#!/usr/bin/env bash
# Shared helpers for agentic-kit shell scripts.
# Source from tools/<script>.sh siblings:
#     source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
# Source from autoresearch/tools/<script>.sh:
#     source "$(cd "$(dirname "$0")/../.." && pwd)/tools/lib.sh"
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Colors & output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  CYAN=$'\033[36m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
  RESET=$'\033[0m'
else
  BOLD='' DIM='' CYAN='' GREEN='' YELLOW='' RED='' RESET=''
fi

info()    { printf "  ${DIM}○ %s${RESET}\n" "$*"; }
success() { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
skip()    { printf "  ${YELLOW}→${RESET} ${DIM}%s${RESET}\n" "$*"; }
warn()    { printf "  ${YELLOW}⚠${RESET} %s\n" "$*"; }
err()     { printf "  ${RED}✗${RESET} %s\n" "$*"; }
header()  { printf "\n${BOLD}${CYAN}  %s${RESET}\n" "$*"; }
removed() { printf "  ${RED}✗${RESET} %s\n" "$*"; }

# Centred banner box for top-level scripts. Width of the inside is 29 chars.
kit_banner() {
  local title="$1"
  local pad_total=$(( 29 - ${#title} ))
  [ $pad_total -lt 0 ] && pad_total=0
  local left=$(( pad_total / 2 ))
  local right=$(( pad_total - left ))
  local ls="" rs="" i
  for ((i=0; i<left;  i++)); do ls+=" "; done
  for ((i=0; i<right; i++)); do rs+=" "; done
  printf "\n${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
  printf   "${BOLD}${CYAN}  │%s%s%s│${RESET}\n" "$ls" "$title" "$rs"
  printf   "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
}

# Standard "yes / non-interactive" flag check. Returns 0 if any of the canonical
# yes aliases is in "$@".
kit_arg_is_yes() {
  local a
  for a in "$@"; do
    case "$a" in
      --yes|-y|--non-interactive|-n) return 0 ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# Kit paths & marker (kit directory = directory containing this file)
# ---------------------------------------------------------------------------
AGENTIC_MARKER='<!-- agentic-kit managed -->'

AGENTIC_BLOCK_BEGIN='<!-- agentic-kit:start -->'
AGENTIC_BLOCK_END='<!-- agentic-kit:end -->'
AGENTIC_GITIGNORE_BEGIN='# >>> agentic-kit (managed) >>>'
AGENTIC_GITIGNORE_END='# <<< agentic-kit (managed) <<<'

ARTEFACTS_NAME="${ARTEFACTS_DIR:-.akt}"

_LIB_SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$_LIB_SELFDIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")
ARTEFACTS="$PROJECT_ROOT/$ARTEFACTS_NAME"
KIT_CFG="$ARTEFACTS/.agentic-kit.cfg"
KIT_FILES_MANIFEST="$ARTEFACTS/.agentic-kit.files"

# One-time migration from older layouts (manifest + cfg at project root).
kit_migrate_legacy_root_state() {
  mkdir -p "$ARTEFACTS"
  local lc="$PROJECT_ROOT/.agentic-kit.cfg"
  local lm="$PROJECT_ROOT/.agentic-kit.files"
  if [ -f "$lc" ] && [ ! -f "$KIT_CFG" ]; then
    mv "$lc" "$KIT_CFG"
    info "migrated .agentic-kit.cfg → $ARTEFACTS_NAME/.agentic-kit.cfg"
  fi
  if [ -f "$lm" ] && [ ! -f "$KIT_FILES_MANIFEST" ]; then
    mv "$lm" "$KIT_FILES_MANIFEST"
    info "migrated .agentic-kit.files → $ARTEFACTS_NAME/.agentic-kit.files"
  fi
}

# ---------------------------------------------------------------------------
# Temp-file tracking with auto-cleanup
# ---------------------------------------------------------------------------
_KIT_TEMP_FILES=()

_kit_cleanup_temps() {
  local f
  for f in "${_KIT_TEMP_FILES[@]:-}"; do
    [ -n "$f" ] && [ -e "$f" ] && rm -rf -- "$f" 2>/dev/null || true
  done
  _KIT_TEMP_FILES=()
}

# Make a tracked temp file/dir. Auto-removed on script EXIT.
# Usage: tmp=$(kit_mktemp [label])  or  tmp=$(kit_mktemp -d [label])
kit_mktemp() {
  local as_dir=false
  if [ "${1:-}" = "-d" ]; then as_dir=true; shift; fi
  local label="${1:-akt}"
  local base="${TMPDIR:-/tmp}"
  [ -d "$base" ] || base="."
  local t
  if $as_dir; then
    t=$(mktemp -d "$base/${label}.XXXXXX") || return 1
  else
    t=$(mktemp "$base/${label}.XXXXXX") || return 1
  fi
  _KIT_TEMP_FILES+=( "$t" )
  printf '%s' "$t"
}

# Only install our trap if the caller hasn't already set one.
if [ -z "$(trap -p EXIT 2>/dev/null)" ]; then
  trap _kit_cleanup_temps EXIT
fi

# ---------------------------------------------------------------------------
# SHA-256 helpers
# ---------------------------------------------------------------------------
_KIT_SHA_CMD=""
_kit_resolve_sha_cmd() {
  [ -n "$_KIT_SHA_CMD" ] && return 0
  if command -v sha256sum &>/dev/null; then
    _KIT_SHA_CMD="sha256sum"
  elif command -v shasum &>/dev/null; then
    _KIT_SHA_CMD="shasum -a 256"
  else
    err "Neither sha256sum nor shasum found — install coreutils."
    return 1
  fi
}

kit_sha256_file() {
  local f="$1"
  if [ ! -f "$f" ] || [ -L "$f" ]; then
    printf ''
    return 1
  fi
  _kit_resolve_sha_cmd || return 1
  $_KIT_SHA_CMD "$f" | awk '{print $1}'
}

kit_sha256_stream_aggregate() {
  _kit_resolve_sha_cmd || return 1
  $_KIT_SHA_CMD | awk '{print $1}'
}

kit_sha256_tree() {
  local dir="$1"
  if [ ! -d "$dir" ] || [ -L "$dir" ]; then
    printf ''
    return 1
  fi
  (
    cd "$dir" || exit 1
    find . -type f | LC_ALL=C sort | while read -r rp; do
      kit_sha256_file "$rp" || true
    done
  ) | kit_sha256_stream_aggregate
}

kit_sha256_string() {
  _kit_resolve_sha_cmd || return 1
  printf '%s' "$1" | $_KIT_SHA_CMD | awk '{print $1}'
}

# ---------------------------------------------------------------------------
# Git-tracked predicate (used to skip rehashing untouched, tracked files)
# ---------------------------------------------------------------------------
# True if $rel (project-relative) is tracked AND has no working-tree/index diff.
kit_is_git_clean() {
  local rel="$1"
  command -v git &>/dev/null || return 1
  ( cd "$PROJECT_ROOT" 2>/dev/null \
    && git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && git ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 \
    && git diff --quiet -- "$rel" 2>/dev/null \
    && git diff --cached --quiet -- "$rel" 2>/dev/null )
}

# ---------------------------------------------------------------------------
# .akt/.agentic-kit.cfg — flat KEY=VALUE store
# ---------------------------------------------------------------------------
kit_cfg_get() {
  local key="$1"
  [ -f "$KIT_CFG" ] || return 1
  awk -F= -v k="$key" 'BEGIN{found=0} $1 == k { sub(/^[^=]+=/, ""); print; found=1; exit } END{ exit !found }' "$KIT_CFG"
}

kit_cfg_set() {
  local key="$1" value="$2"
  mkdir -p "$(dirname "$KIT_CFG")"
  touch "$KIT_CFG"
  local tmp
  tmp=$(kit_mktemp "akt-cfg") || return 1
  awk -F= -v k="$key" '$1 != k' "$KIT_CFG" > "$tmp"
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$KIT_CFG"
}

# Write multiple key=value pairs in one rewrite. Args: key1 val1 key2 val2 ...
kit_cfg_set_many() {
  mkdir -p "$(dirname "$KIT_CFG")"
  touch "$KIT_CFG"
  local -a keys=() vals=()
  while [ $# -ge 2 ]; do
    keys+=( "$1" ); vals+=( "$2" ); shift 2
  done
  local pat="" k
  for k in "${keys[@]}"; do pat+="|^${k}="; done
  pat="${pat#|}"
  local tmp
  tmp=$(kit_mktemp "akt-cfg") || return 1
  if [ -n "$pat" ]; then
    awk -v pat="$pat" '$0 !~ pat' "$KIT_CFG" > "$tmp" || true
  else
    cat "$KIT_CFG" > "$tmp"
  fi
  local i
  for i in "${!keys[@]}"; do
    printf '%s=%s\n' "${keys[$i]}" "${vals[$i]}" >> "$tmp"
  done
  mv "$tmp" "$KIT_CFG"
}

# ---------------------------------------------------------------------------
# Install manifest (.akt/.agentic-kit.files: relpath<TAB>hash)
#
# Two modes:
#   * Direct (default): each set/remove rewrites the file. Fine for one-shot ops.
#   * Transactional: wrap a batch in manifest_begin / manifest_commit. Edits go
#     to an in-memory map; one atomic write happens at commit. Init.sh uses this.
# ---------------------------------------------------------------------------
declare -A _KIT_MANIFEST_BUF=()
_KIT_MANIFEST_DIRTY=false
_KIT_MANIFEST_LOADED=false

manifest_ensure_file() {
  mkdir -p "$(dirname "$KIT_FILES_MANIFEST")" 2>/dev/null || true
  touch "$KIT_FILES_MANIFEST"
}

manifest_begin() {
  _KIT_MANIFEST_BUF=()
  _KIT_MANIFEST_DIRTY=false
  _KIT_MANIFEST_LOADED=true
  manifest_ensure_file
  local path hash
  while IFS=$'\t' read -r path hash; do
    [ -z "$path" ] && continue
    _KIT_MANIFEST_BUF["$path"]="$hash"
  done < "$KIT_FILES_MANIFEST"
}

manifest_commit() {
  $_KIT_MANIFEST_LOADED || return 0
  if $_KIT_MANIFEST_DIRTY; then
    manifest_ensure_file
    local tmp k
    tmp=$(kit_mktemp "akt-manifest") || return 1
    for k in "${!_KIT_MANIFEST_BUF[@]}"; do
      printf '%s\t%s\n' "$k" "${_KIT_MANIFEST_BUF[$k]}" >> "$tmp"
    done
    LC_ALL=C sort "$tmp" -o "$tmp"
    mv "$tmp" "$KIT_FILES_MANIFEST"
  fi
  _KIT_MANIFEST_BUF=()
  _KIT_MANIFEST_DIRTY=false
  _KIT_MANIFEST_LOADED=false
}

# Abort a transaction without writing. Useful in error paths.
manifest_abort() {
  _KIT_MANIFEST_BUF=()
  _KIT_MANIFEST_DIRTY=false
  _KIT_MANIFEST_LOADED=false
}

manifest_remove_entry() {
  local rel="$1"
  if $_KIT_MANIFEST_LOADED; then
    if [ -n "${_KIT_MANIFEST_BUF[$rel]+x}" ]; then
      unset "_KIT_MANIFEST_BUF[$rel]"
      _KIT_MANIFEST_DIRTY=true
    fi
    return 0
  fi
  manifest_ensure_file
  local tmp
  tmp=$(kit_mktemp "akt-manifest") || return 1
  awk -F'\t' -v p="$rel" 'BEGIN{FS=OFS="\t"} $1 != p || NF < 2 {print}' "$KIT_FILES_MANIFEST" >"$tmp"
  mv "$tmp" "$KIT_FILES_MANIFEST"
}

manifest_set_hash() {
  local rel="$1" hash="$2"
  if $_KIT_MANIFEST_LOADED; then
    _KIT_MANIFEST_BUF["$rel"]="$hash"
    _KIT_MANIFEST_DIRTY=true
    return 0
  fi
  manifest_remove_entry "$rel"
  manifest_ensure_file
  printf '%s\t%s\n' "$rel" "$hash" >>"$KIT_FILES_MANIFEST"
}

manifest_get_hash() {
  local rel="$1"
  if $_KIT_MANIFEST_LOADED; then
    printf '%s' "${_KIT_MANIFEST_BUF[$rel]:-}"
    return 0
  fi
  [ -f "$KIT_FILES_MANIFEST" ] || return 1
  awk -F'\t' -v p="$rel" '$1 == p {print $2}' "$KIT_FILES_MANIFEST" | tail -n1
}

# Legacy kit symlink: relative link targets ../../$SUBMODULE_DIR/...
kit_symlink_points_into_kit() {
  local link="$1"
  [ -L "$link" ] || return 1
  local rl
  rl=$(readlink "$link")
  case "$rl" in
    ../../"$SUBMODULE_DIR"/*|../"$SUBMODULE_DIR"/*|*"${SUBMODULE_DIR}/"agents/*|*"${SUBMODULE_DIR}/"skills/*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Managed blocks (CLAUDE.md / AGENTS.md / .gitignore)
#
# Single strip implementation parameterised by begin/end markers; thin wrappers
# preserve the prior API (agentic_block_*, agentic_gitignore_*).
# ---------------------------------------------------------------------------

_kit_block_present() {
  local file="$1" begin="$2"
  [ -f "$file" ] || return 1
  grep -qF "$begin" "$file" 2>/dev/null
}

# Strip a managed block bounded by begin/end markers (idempotent).
# Returns 0 if a block was removed, 1 if no block was present, 2 on error.
_kit_strip_block() {
  local file="$1" begin="$2" end="$3"
  [ -f "$file" ] || return 1
  _kit_block_present "$file" "$begin" || return 1

  local tmp trimmed
  tmp=$(kit_mktemp "akt-strip") || return 2

  awk -v b="$begin" -v e="$end" '
    BEGIN { skip=0 }
    {
      if (skip == 0 && index($0, b) > 0) { skip=1; next }
      if (skip == 1) {
        if (index($0, e) > 0) { skip=2; next }
        next
      }
      if (skip == 2) { skip=3; if ($0 == "") next }
      print
    }
  ' "$file" > "$tmp" || return 2

  trimmed=$(kit_mktemp "akt-strip") || return 2
  awk '
    { lines[NR]=$0 }
    END {
      n=NR
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      for (i=1; i<=n; i++) print lines[i]
    }
  ' "$tmp" > "$trimmed" || return 2
  mv "$trimmed" "$file"
  return 0
}

# Render the include block. Arg: pipeline_rel (relative path).
agentic_block_render() {
  local pipeline_rel="$1"
  cat <<EOF
$AGENTIC_BLOCK_BEGIN
<!--
  This block is managed by agentic-kit.
  Do not edit between the start/end markers — re-run \`agentic-kit/init.sh\` to refresh it,
  or \`agentic-kit/teardown.sh\` to remove it. Everything outside the markers is yours.
-->

> **Agentic Kit pipeline** — read [\`$pipeline_rel\`]($pipeline_rel) before any task.
> It defines the agent roles, handoff protocol, and quality gates used in this project.
> Project-specific config: [\`$ARTEFACTS_NAME/PROJECT.md\`]($ARTEFACTS_NAME/PROJECT.md).

@$pipeline_rel
$AGENTIC_BLOCK_END
EOF
}

agentic_block_present() { _kit_block_present "$1" "$AGENTIC_BLOCK_BEGIN"; }
agentic_block_strip()   { _kit_strip_block  "$1" "$AGENTIC_BLOCK_BEGIN" "$AGENTIC_BLOCK_END"; }

agentic_block_write_stub() {
  local file="$1" pipeline_rel="$2"
  mkdir -p "$(dirname "$file")"
  {
    printf '# %s\n\n' "$(basename "$file" .md)"
    printf 'This file is read by your IDE on every prompt. Add project-specific guidance below the managed block.\n\n'
    agentic_block_render "$pipeline_rel"
    printf '\n'
  } > "$file"
}

agentic_block_append() {
  local file="$1" pipeline_rel="$2"
  if [ -s "$file" ]; then
    local last_byte
    last_byte=$(tail -c1 "$file" 2>/dev/null || true)
    if [ "$last_byte" != $'\n' ]; then
      printf '\n' >> "$file"
    fi
    printf '\n' >> "$file"
  fi
  agentic_block_render "$pipeline_rel" >> "$file"
}

# ---------------------------------------------------------------------------
# Managed .gitignore block
# ---------------------------------------------------------------------------
agentic_gitignore_render() {
  cat <<EOF
$AGENTIC_GITIGNORE_BEGIN
# Managed by agentic-kit. Re-run \`agentic-kit/init.sh\` to refresh, or
# \`agentic-kit/teardown.sh\` to remove the whole block. Edits inside this block
# are overwritten on init.
#
# --- Runtime / ephemeral (pipeline scratch; usually not committed) ---
$ARTEFACTS_NAME/memory/
$ARTEFACTS_NAME/features/
$ARTEFACTS_NAME/archive/
$ARTEFACTS_NAME/proposed-patches/
$ARTEFACTS_NAME/scratch/
$ARTEFACTS_NAME/SESSION-STATE.md
$ARTEFACTS_NAME/MEMORY.md
$ARTEFACTS_NAME/PROJECT_PROFILE.md
#
# --- Per-machine kit bookkeeping (usually not committed) ---
$ARTEFACTS_NAME/.agentic-kit.cfg
$ARTEFACTS_NAME/.agentic-kit.files
#
# Optional — ignore all of $ARTEFACTS_NAME/ except PIPELINE.md + PROJECT.md (uncomment all 4 lines):
# $ARTEFACTS_NAME/**
# !$ARTEFACTS_NAME/
# !$ARTEFACTS_NAME/PIPELINE.md
# !$ARTEFACTS_NAME/PROJECT.md
#
$AGENTIC_GITIGNORE_END
EOF
}

agentic_gitignore_present() { _kit_block_present "$1" "$AGENTIC_GITIGNORE_BEGIN"; }
agentic_gitignore_strip()   { _kit_strip_block  "$1" "$AGENTIC_GITIGNORE_BEGIN" "$AGENTIC_GITIGNORE_END"; }

# ---------------------------------------------------------------------------
# Managed-file teardown helpers (shared by teardown.sh and update.sh).
# Callers may set DRY_RUN=true to preview without touching the filesystem.
# ---------------------------------------------------------------------------

kit_rm() {
  if [ "${DRY_RUN:-false}" = "true" ]; then
    info "would remove: $1"
  else
    rm "$1"
  fi
}

kit_rm_rf() {
  if [ "${DRY_RUN:-false}" = "true" ]; then
    info "would remove: $1"
  else
    rm -rf "$1"
  fi
}

_manifest_drop() {
  if [ "${DRY_RUN:-false}" != "true" ]; then manifest_remove_entry "$1"; fi
}

# Remove a regular file if the manifest hash matches (or legacy kit marker, no manifest).
kit_managed_file_remove() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -f "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a regular file — delete manually)"
    return 1
  fi

  have=$(kit_sha256_file "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && grep -qF "$AGENTIC_MARKER" "$abs" 2>/dev/null; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy kit marker, no manifest)"
    return 0
  fi

  skip "$rel (modified or unknown — hash mismatch or not kit-managed)"
  return 1
}

# Remove a copied tree if the manifest hash matches (or matches live kit source).
kit_managed_tree_remove() {
  local rel="$1"
  local kit_src="$2"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have want

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    kit_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -d "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a directory — delete manually)"
    return 1
  fi

  have=$(kit_sha256_tree "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    kit_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && [ -d "$kit_src" ]; then
    want=$(kit_sha256_tree "$kit_src") || true
    if [ -n "$want" ] && [ -n "$have" ] && [ "$have" = "$want" ]; then
      kit_rm_rf "$abs"
      _manifest_drop "$rel"
      removed "$rel (matches kit source, no manifest)"
      return 0
    fi
  fi

  skip "$rel (modified locally — hash mismatch)"
  return 1
}

# Strip the kit-managed include block from $rel (a project-relative path).
# Behaviour:
#   * if the manifest entry says "stub:<sha>" and the file still matches that
#     stub byte-for-byte (we created it), remove the whole file
#   * else strip just the marked block and keep the rest of the file
#   * always drop the manifest entry
kit_include_block_remove() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded prefix value have

  if [ ! -f "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  recorded=$(manifest_get_hash "$rel" || true)
  prefix="${recorded%%:*}"
  value="${recorded#*:}"

  if [ "$prefix" = "stub" ] && [ -n "$value" ]; then
    have=$(kit_sha256_file "$abs" || true)
    if [ -n "$have" ] && [ "$have" = "$value" ]; then
      kit_rm "$abs"
      _manifest_drop "$rel"
      removed "$rel (kit-created stub)"
      return 0
    fi
  fi

  if agentic_block_present "$abs"; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
      info "would strip managed include block from: $rel"
      return 0
    fi
    if agentic_block_strip "$abs"; then
      _manifest_drop "$rel"
      removed "$rel (managed block stripped, file kept)"
      return 0
    fi
    warn "$rel (failed to strip block — left as-is)"
    return 1
  fi

  if [ -n "$recorded" ]; then
    skip "$rel (no managed block found — manifest entry dropped)"
    _manifest_drop "$rel"
    return 0
  fi

  skip "$rel (no managed block — leaving file alone)"
}
