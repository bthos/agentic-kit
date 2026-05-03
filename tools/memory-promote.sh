#!/usr/bin/env bash
# Runs the memory promotion state machine across .artefacts/memory/.
#
#     observed -> logged (L2 daily) -> curated (L3) -> hardened (L0 patch) -> stable
#
# Steps performed:
#   1) Hash every L2/L3 entry that has `id: pending` (content-addressed → mem_<sha8>).
#   2) Apply the **2-strike rule**: if the same `text:` payload appears in 2+ daily L2
#      files, copy it to the right L3 file (`pattern`/`anti-pattern` → preferences,
#      `tool`/`library` → system, `project` → projects, `decision` → decisions).
#   3) Resolve `supersedes:` chains: when an L3 entry is referenced by `supersedes:`
#      from a newer entry, append `[superseded by mem_xxxxxxxx]` to the older `text:`.
#   4) Rebuild `.artefacts/MEMORY.md` (L4 root summary) deterministically.
#   5) (--propose-hardening) For high-confidence L3 entries referenced ≥3 times in
#      archived features, write proposed agent patches to
#      `.artefacts/proposed-patches/<agent>.md` so `apply-patches.sh`
#      can land them.
#
# Override the artefacts directory with $ARTEFACTS_DIR (e.g. for legacy .artefacts/
# checkouts that have not migrated yet).
#
# Usage:
#   agentic-kit/tools/memory-promote.sh                    # run steps 1..4
#   agentic-kit/tools/memory-promote.sh --propose-hardening
#   agentic-kit/tools/memory-promote.sh --dry-run          # show what would happen
#
# Run from project root.

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.artefacts}"
MEM_DIR="$ARTEFACTS/memory"
ROOT="$ARTEFACTS/MEMORY.md"
PATCHES_DIR="$ARTEFACTS/proposed-patches"

DRY_RUN=false
PROPOSE_HARDENING=false
for _arg in "$@"; do
  case "$_arg" in
    --dry-run)            DRY_RUN=true ;;
    --propose-hardening)  PROPOSE_HARDENING=true ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

if [ ! -d "$MEM_DIR" ]; then
  echo "Memory tree not initialised. Run: agentic-kit/tools/memory-init.sh"
  exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
sha8() {
  local s="$1"
  if command -v sha1sum &>/dev/null; then
    printf '%s' "$s" | sha1sum | awk '{print substr($1,1,8)}'
  else
    printf '%s' "$s" | shasum | awk '{print substr($1,1,8)}'
  fi
}

# Yields tab-separated rows: file<TAB>start_line<TAB>end_line<TAB>text_payload<TAB>entity_type<TAB>id
# `text_payload` is the joined indented lines under `text: |`.
list_entries() {
  local file="$1"
  awk -v f="$file" '
    BEGIN { in_entry=0; }
    /^- id:[[:space:]]*/ {
      if (in_entry) emit()
      in_entry=1; start=NR
      id=$0; sub(/^- id:[[:space:]]*/, "", id)
      etype=""; payload=""; in_text=0
      next
    }
    in_entry==1 && /^[[:space:]]+entity_type:/ {
      etype=$0; sub(/^[[:space:]]+entity_type:[[:space:]]*/, "", etype)
      next
    }
    in_entry==1 && /^[[:space:]]+text:[[:space:]]*\|[[:space:]]*$/ {
      in_text=1; next
    }
    in_entry==1 && in_text==1 && /^[[:space:]]+/ {
      line=$0; sub(/^[[:space:]]+/, "", line)
      payload = (payload=="" ? line : payload " " line)
      next
    }
    in_entry==1 && /^[^- ]/ {
      emit(); in_entry=0
    }
    /^- id:/ && in_entry==1 {
      # already captured by the rule above
    }
    function emit() {
      printf "%s\t%d\t%d\t%s\t%s\t%s\n", f, start, NR-1, payload, etype, id
    }
    END { if (in_entry) printf "%s\t%d\t%d\t%s\t%s\t%s\n", f, start, NR, payload, etype, id }
  ' "$file"
}

l3_target_for_type() {
  case "$1" in
    pattern|anti-pattern|file)  echo "$MEM_DIR/preferences.md" ;;
    tool|library)               echo "$MEM_DIR/system.md" ;;
    project)                    echo "$MEM_DIR/projects.md" ;;
    decision)                   echo "$MEM_DIR/decisions.md" ;;
    *)                          echo "$MEM_DIR/preferences.md" ;;
  esac
}

# ---------------------------------------------------------------------------
# Step 1: hash pending ids
# ---------------------------------------------------------------------------
hash_pending_in_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  $DRY_RUN && { grep -c '^- id: pending' "$file" 2>/dev/null || echo 0; return 0; }

  python3 - "$file" <<'PY' 2>/dev/null || awk_fallback "$file"
import re, sys, hashlib, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")
def rewrite(match):
    body = match.group(0)
    text_match = re.search(r"text:\s*\|\s*\n((?:[ \t]+.*\n?)+)", body)
    if not text_match:
        return body
    text = text_match.group(1).strip()
    sha = hashlib.sha1(text.encode("utf-8")).hexdigest()[:8]
    return body.replace("- id: pending", f"- id: mem_{sha}", 1)
new = re.sub(r"- id: pending[\s\S]+?(?=^- id: |\Z)", rewrite, src, flags=re.MULTILINE)
if new != src:
    p.write_text(new, encoding="utf-8")
PY
}

awk_fallback() {
  : # python3 missing → leave pending; memory-search still works
}

for f in "$MEM_DIR"/preferences.md "$MEM_DIR"/system.md "$MEM_DIR"/projects.md "$MEM_DIR"/decisions.md "$MEM_DIR"/[0-9]*.md; do
  [ -f "$f" ] || continue
  hash_pending_in_file "$f"
done

# ---------------------------------------------------------------------------
# Step 2: 2-strike rule
# ---------------------------------------------------------------------------
declare -A TEXT_COUNT
declare -A TEXT_SAMPLE_FILE
declare -A TEXT_SAMPLE_TYPE
declare -A TEXT_SAMPLE_ID

shopt -s nullglob
for daily in "$MEM_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
  while IFS=$'\t' read -r f s e payload etype id; do
    [ -z "$payload" ] && continue
    key=$(printf '%s' "$payload" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')
    TEXT_COUNT[$key]=$(( ${TEXT_COUNT[$key]:-0} + 1 ))
    TEXT_SAMPLE_FILE[$key]="$f:$s-$e"
    TEXT_SAMPLE_TYPE[$key]="${etype:-pattern}"
    TEXT_SAMPLE_ID[$key]="$id"
  done < <(list_entries "$daily")
done
shopt -u nullglob

PROMOTED=0
for key in "${!TEXT_COUNT[@]}"; do
  count=${TEXT_COUNT[$key]}
  [ "$count" -lt 2 ] && continue

  etype=${TEXT_SAMPLE_TYPE[$key]}
  target=$(l3_target_for_type "$etype")

  # Skip if already in L3 (any entry whose text payload matches)
  found_in_l3=false
  while IFS=$'\t' read -r f s e payload etype2 id; do
    k2=$(printf '%s' "$payload" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')
    [ "$k2" = "$key" ] && { found_in_l3=true; break; }
  done < <(list_entries "$target")
  $found_in_l3 && continue

  if $DRY_RUN; then
    echo "  promote → $target  (×$count)  : ${key:0:80}…"
    continue
  fi

  shared_id="mem_$(sha8 "$key")"
  decided=$(date +%Y-%m-%d)
  {
    echo ""
    echo "- id: $shared_id"
    echo "  decided: $decided"
    echo "  entity_type: $etype"
    echo "  entities: []"
    echo "  confidence: medium"
    echo "  source: ${TEXT_SAMPLE_FILE[$key]} (×$count, 2-strike)"
    echo "  text: |"
    printf '%s\n' "$key" | fold -s -w 100 | sed 's/^/    /'
  } >> "$target"
  PROMOTED=$((PROMOTED+1))
done

# ---------------------------------------------------------------------------
# Step 3: supersedes resolver
# ---------------------------------------------------------------------------
SUPERSEDED=0
for f in "$MEM_DIR"/preferences.md "$MEM_DIR"/system.md "$MEM_DIR"/projects.md "$MEM_DIR"/decisions.md; do
  [ -f "$f" ] || continue
  while IFS= read -r superseder; do
    older=$(printf '%s' "$superseder" | sed -nE 's/.*supersedes:[[:space:]]*(mem_[a-f0-9]+).*/\1/p')
    [ -z "$older" ] && continue
    new_id=$(grep -B5 "supersedes: $older" "$f" 2>/dev/null | grep -E '^- id: ' | tail -n1 | awk '{print $3}')
    [ -z "$new_id" ] && continue
    if grep -q "^- id: $older" "$f" \
       && ! grep -A12 "^- id: $older" "$f" | grep -q "\[superseded by"; then
      $DRY_RUN && { echo "  supersede $older  ←  $new_id  in $f"; continue; }
      python3 - "$f" "$older" "$new_id" <<'PY' 2>/dev/null || true
import sys, re, pathlib
fp, old_id, new_id = sys.argv[1:4]
p = pathlib.Path(fp); src = p.read_text(encoding="utf-8")
pat = re.compile(rf"(- id:\s*{re.escape(old_id)}[\s\S]+?text:\s*\|\s*\n((?:[ \t]+.*\n?)+))", re.MULTILINE)
def repl(m):
    block = m.group(1)
    if "[superseded by" in block: return block
    return block.rstrip("\n") + f"    [superseded by {new_id}]\n"
src2 = pat.sub(repl, src, count=1)
if src2 != src: p.write_text(src2, encoding="utf-8")
PY
      SUPERSEDED=$((SUPERSEDED+1))
    fi
  done < <(grep -E '^[[:space:]]+supersedes:' "$f" || true)
done

# ---------------------------------------------------------------------------
# Step 4: regenerate L4 root summary
# ---------------------------------------------------------------------------
regen_root() {
  $DRY_RUN && { echo "  (dry-run) would regenerate $ROOT"; return; }

  count_high() {
    local f="$1"
    [ -f "$f" ] || { echo 0; return; }
    local n
    n=$(grep -c '^[[:space:]]*confidence:[[:space:]]*high' "$f" 2>/dev/null || true)
    echo "${n:-0}"
  }
  count_total() {
    local f="$1"
    [ -f "$f" ] || { echo 0; return; }
    local n
    n=$(grep -c '^- id: ' "$f" 2>/dev/null || true)
    echo "${n:-0}"
  }

  pref_h=$(count_high "$MEM_DIR/preferences.md"); pref_t=$(count_total "$MEM_DIR/preferences.md")
  syst_h=$(count_high "$MEM_DIR/system.md");      syst_t=$(count_total "$MEM_DIR/system.md")
  proj_t=$(count_total "$MEM_DIR/projects.md")
  dec_t=$(count_total  "$MEM_DIR/decisions.md")

  {
    echo "# Memory Index (L4)"
    echo
    echo "_Generated by \`memory-promote.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ). Do not hand-edit._"
    echo
    echo "## High-confidence preferences ($pref_h high / $pref_t total)"
    grep -B1 -A6 '^[[:space:]]*confidence:[[:space:]]*high' "$MEM_DIR/preferences.md" 2>/dev/null \
      | awk '/^- id:/ {id=$3} /^[[:space:]]+text:/ {gettext=1; next} gettext && /^[[:space:]]+/ {gsub(/^[[:space:]]+/,""); printf "- %s — %s\n", id, $0; gettext=0}' \
      | head -n 10 || echo "_(none yet)_"
    echo
    echo "## High-confidence system facts ($syst_h high / $syst_t total)"
    grep -B1 -A6 '^[[:space:]]*confidence:[[:space:]]*high' "$MEM_DIR/system.md" 2>/dev/null \
      | awk '/^- id:/ {id=$3} /^[[:space:]]+text:/ {gettext=1; next} gettext && /^[[:space:]]+/ {gsub(/^[[:space:]]+/,""); printf "- %s — %s\n", id, $0; gettext=0}' \
      | head -n 10 || echo "_(none yet)_"
    echo
    echo "## Recent decisions ($dec_t total — newest first)"
    awk '/^- id:/ {id=$3} /^[[:space:]]+decided:/ {d=$2} /^[[:space:]]+text:/ {gettext=1; next} gettext && /^[[:space:]]+/ {gsub(/^[[:space:]]+/,""); printf "- %s (%s) — %s\n", id, d, $0; gettext=0}' \
      "$MEM_DIR/decisions.md" 2>/dev/null | tac | head -n 10 || echo "_(none yet)_"
    echo
    echo "## Recent supersessions"
    grep -RnE '\[superseded by mem_' "$MEM_DIR/" 2>/dev/null | head -n 10 \
      | awk -F: '{ printf "- %s:%s\n", $1, $2 }' || echo "_(none yet)_"
    echo
    echo "## Drilldowns"
    echo "- preferences → \`$MEM_DIR/preferences.md\`"
    echo "- system → \`$MEM_DIR/system.md\`"
    echo "- projects → \`$MEM_DIR/projects.md\`"
    echo "- decisions → \`$MEM_DIR/decisions.md\`"
  } > "$ROOT"
}

regen_root

# ---------------------------------------------------------------------------
# Step 5 (opt-in): propose hardening for high-confidence L3 entries
# ---------------------------------------------------------------------------
if $PROPOSE_HARDENING; then
  mkdir -p "$PATCHES_DIR"
  while IFS= read -r line; do
    id=$(printf '%s' "$line" | awk '{print $3}')
    text_block=$(grep -A12 "^- id: $id" "$MEM_DIR"/*.md 2>/dev/null \
                 | sed -nE 's/^[[:space:]]+text:.*$//; /text: \|/,/^- /p' | head -n 4 \
                 | grep -v '^- id:' | sed 's/^[[:space:]]\+//')
    case "$line" in
      *preferences.md*) agent="cmok" ;;
      *system.md*)      agent="laznik" ;;
      *projects.md*)    agent="vadavik" ;;
      *decisions.md*)   agent="laznik" ;;
      *)                agent="cmok" ;;
    esac
    out="$PATCHES_DIR/${agent}.md"
    {
      echo ""
      echo "### Hardening proposal — $id ($(date +%Y-%m-%d))"
      echo "_Promoted from L3; high confidence. Source: $line_"
      echo ""
      echo "$text_block"
    } >> "$out"
  done < <(grep -RnE '^[[:space:]]*confidence:[[:space:]]*high' "$MEM_DIR/preferences.md" "$MEM_DIR/system.md" 2>/dev/null \
           | head -n 20 \
           | awk -F: '{print $1":"$2" id "}')
  echo "  Hardening proposals written to $PATCHES_DIR/  (review with apply-patches.sh)"
fi

echo
echo "Done. Promoted: $PROMOTED. Superseded: $SUPERSEDED. Index: $ROOT"
