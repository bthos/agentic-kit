#!/usr/bin/env bash
# Append one structured entry to today's L2 daily memory file, then (unless
# --no-promote) run the promotion state machine so L3/L4 stay current.
#
# This is the deterministic seam that closes the "agent forgets to remember"
# gap: agents call this single command instead of hand-writing YAML. A
# `--confidence high` entry is promoted to L3 immediately (single-shot
# curation); medium/low entries wait for the 2-strike rule.
#
#   observed → logged (L2, here) → curated (L3, via promote.sh) → …
#
# Usage:
#   memory/tools/log.sh --type pattern "Prefer composition over inheritance."
#   memory/tools/log.sh --type decision --confidence high \
#       --entities "api,auth" --source "feat/login" "Adopt OAuth device flow."
#   echo "long fact on stdin" | memory/tools/log.sh --type tool
#
# Options:
#   --type TYPE         entity_type — one of:
#                       person project file tool library pattern anti-pattern decision
#   --confidence C      high | medium | low   (default: medium)
#                       high → promoted straight to L3 by promote.sh
#   --entities "a,b"    comma-separated related entities (default: none)
#   --source S          provenance note (default: "log.sh")
#   --no-promote        append only; do not run promote.sh
#   --dry-run           print the entry to stdout; write nothing
#   -h, --help
#
# Override the artefacts directory with $ARTEFACTS_DIR (default: .tlk).
# Run from project root.

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
MEM_DIR="$ARTEFACTS/memory"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

TYPE=""
CONFIDENCE="medium"
ENTITIES=""
SOURCE="log.sh"
NO_PROMOTE=false
DRY_RUN=false
TEXT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --type)        TYPE="$2"; shift 2 ;;
    --confidence)  CONFIDENCE="$2"; shift 2 ;;
    --entities)    ENTITIES="$2"; shift 2 ;;
    --source)      SOURCE="$2"; shift 2 ;;
    --no-promote)  NO_PROMOTE=true; shift ;;
    --dry-run)     DRY_RUN=true; shift ;;
    -h|--help)     sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --)            shift; break ;;
    -*)            echo "Unknown option: $1" >&2; exit 2 ;;
    *)             TEXT="${TEXT:+$TEXT }$1"; shift ;;
  esac
done
# Any remaining args after `--`
[ $# -gt 0 ] && TEXT="${TEXT:+$TEXT }$*"

# Text may also arrive on stdin (when not a TTY and no positional text given).
if [ -z "$TEXT" ] && [ ! -t 0 ]; then
  TEXT="$(cat)"
fi

# --- Validation -----------------------------------------------------------
case "$TYPE" in
  person|project|file|tool|library|pattern|anti-pattern|decision) ;;
  "") echo "--type is required (person|project|file|tool|library|pattern|anti-pattern|decision)" >&2; exit 2 ;;
  *)  echo "Invalid --type '$TYPE'. Allowed: person project file tool library pattern anti-pattern decision" >&2; exit 2 ;;
esac
case "$CONFIDENCE" in
  high|medium|low) ;;
  *) echo "Invalid --confidence '$CONFIDENCE'. Allowed: high medium low" >&2; exit 2 ;;
esac
TEXT="$(printf '%s' "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$TEXT" ] || { echo "No text provided (positional arg or stdin)." >&2; exit 2; }

# Normalise --entities "a, b , c" → [a, b, c]
fmt_entities() {
  local raw="$1" out="" tok
  raw="${raw//,/ }"
  for tok in $raw; do out="${out:+$out, }$tok"; done
  printf '[%s]' "$out"
}

TODAY="$(date +%Y-%m-%d)"
DAILY="$MEM_DIR/$TODAY.md"

render_entry() {
  printf -- '\n- id: pending\n'
  printf -- '  decided: %s\n' "$TODAY"
  printf -- '  entity_type: %s\n' "$TYPE"
  printf -- '  entities: %s\n' "$(fmt_entities "$ENTITIES")"
  printf -- '  confidence: %s\n' "$CONFIDENCE"
  printf -- '  source: %s\n' "$SOURCE"
  printf -- '  text: |\n'
  printf '%s\n' "$TEXT" | fold -s -w 100 | sed 's/^/    /'
}

if $DRY_RUN; then
  echo "(dry-run) would append to $DAILY:"
  render_entry
  exit 0
fi

mkdir -p "$MEM_DIR"
if [ ! -f "$DAILY" ]; then
  printf '# Daily memory — %s (L2)\n\n_Append-only log. Rolled into L3 by `memory/tools/promote.sh`._\n\n## Observations\n' "$TODAY" > "$DAILY"
fi
render_entry >> "$DAILY"
echo "Logged ($TYPE, $CONFIDENCE) → $DAILY"

if ! $NO_PROMOTE && [ -x "$SELF_DIR/promote.sh" ]; then
  ARTEFACTS_DIR="$ARTEFACTS" "$SELF_DIR/promote.sh" >/dev/null 2>&1 || true
  echo "Promotion run complete (L3/L4 refreshed)."
fi
