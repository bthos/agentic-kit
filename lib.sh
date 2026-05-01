#!/usr/bin/env bash
# Shared helpers for agentic-kit shell scripts.
# Source from init.sh / update.sh / teardown.sh:  source "$(dirname "$0")/lib.sh"
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Colors & output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  CYAN='\033[36m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  RESET='\033[0m'
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

# ---------------------------------------------------------------------------
# Kit paths & marker (kit directory = directory containing this file)
# ---------------------------------------------------------------------------
AGENTIC_MARKER='<!-- agentic-kit managed -->'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")
KIT_CFG="$PROJECT_ROOT/.agentic-kit.cfg"
# Tab-separated: relative_path<TAB>sha256 — paths relative to PROJECT_ROOT, `/` separators
KIT_FILES_MANIFEST="$PROJECT_ROOT/.agentic-kit.files"

# ---------------------------------------------------------------------------
# SHA-256 + install manifest (copies instead of symlinks)
# ---------------------------------------------------------------------------
kit_sha256_file() {
  local f="$1"
  if [ ! -f "$f" ] || [ -L "$f" ]; then
    printf ''
    return 1
  fi
  if command -v sha256sum &>/dev/null; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    err "Neither sha256sum nor shasum found — install coreutils."
    return 1
  fi
}

# Deterministic aggregate hash of all regular files under dir (relative paths sorted).
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

kit_sha256_stream_aggregate() {
  if command -v sha256sum &>/dev/null; then
    sha256sum | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    shasum -a 256 | awk '{print $1}'
  fi
}

manifest_ensure_file() {
  touch "$KIT_FILES_MANIFEST" 2>/dev/null || mkdir -p "$(dirname "$KIT_FILES_MANIFEST")"
  touch "$KIT_FILES_MANIFEST"
}

# Remove line starting with rel_path<TAB>
manifest_remove_entry() {
  local rel="$1"
  manifest_ensure_file
  local tmp
  tmp=$(mktemp "${KIT_FILES_MANIFEST}.XXXXXX")
  awk -F'\t' -v p="$rel" 'BEGIN{FS=OFS="\t"} $1 != p || NF < 2 {print}' "$KIT_FILES_MANIFEST" >"$tmp"
  mv "$tmp" "$KIT_FILES_MANIFEST"
}

manifest_set_hash() {
  local rel="$1" hash="$2"
  manifest_remove_entry "$rel"
  manifest_ensure_file
  printf '%s\t%s\n' "$rel" "$hash" >>"$KIT_FILES_MANIFEST"
}

manifest_get_hash() {
  local rel="$1"
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
