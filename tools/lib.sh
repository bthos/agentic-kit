#!/usr/bin/env bash
# Shared helpers for agentic-kit shell scripts.
# Source from tools/init.sh / tools/update.sh / tools/teardown.sh (siblings in tools/):
#     source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
# Source from tools/<script>.sh siblings:
#     source "$(cd "$(dirname "$0")" && pwd)/lib.sh"
# Source from autoresearch/tools/<script>.sh:
#     source "$(cd "$(dirname "$0")/../.." && pwd)/tools/lib.sh"
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

# Marker block delimiters used inside CLAUDE.md / AGENTS.md / copilot-instructions.md
# and inside .gitignore. The marker form is intentionally distinctive so users (and
# teardown.sh) can grep for it; never edit the markers by hand.
AGENTIC_BLOCK_BEGIN='<!-- agentic-kit:start -->'
AGENTIC_BLOCK_END='<!-- agentic-kit:end -->'
AGENTIC_GITIGNORE_BEGIN='# >>> agentic-kit (managed) >>>'
AGENTIC_GITIGNORE_END='# <<< agentic-kit (managed) <<<'

# Single home for all kit-managed project artefacts (memory, features, archive,
# pipeline copy, project config). Override with $ARTEFACTS_DIR_NAME if a downstream
# project ever needs a different folder name.
ARTEFACTS_DIR_NAME="${ARTEFACTS_DIR_NAME:-.akt}"

# This file lives at agentic-kit/tools/lib.sh — SCRIPT_DIR is always the kit root
# (the directory that contains init.sh, teardown.sh, templates/, agents/, …).
_LIB_SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$_LIB_SELFDIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")
ARTEFACTS_DIR="$PROJECT_ROOT/$ARTEFACTS_DIR_NAME"
KIT_CFG="$ARTEFACTS_DIR/.agentic-kit.cfg"
# Tab-separated: relative_path<TAB>sha256 — paths relative to PROJECT_ROOT, `/` separators
KIT_FILES_MANIFEST="$ARTEFACTS_DIR/.agentic-kit.files"

# One-time migration from older layouts (manifest + cfg at project root).
kit_migrate_legacy_root_state() {
  mkdir -p "$ARTEFACTS_DIR"
  local lc="$PROJECT_ROOT/.agentic-kit.cfg"
  local lm="$PROJECT_ROOT/.agentic-kit.files"
  if [ -f "$lc" ] && [ ! -f "$KIT_CFG" ]; then
    mv "$lc" "$KIT_CFG"
    info "migrated .agentic-kit.cfg → $ARTEFACTS_DIR_NAME/.agentic-kit.cfg"
  fi
  if [ -f "$lm" ] && [ ! -f "$KIT_FILES_MANIFEST" ]; then
    mv "$lm" "$KIT_FILES_MANIFEST"
    info "migrated .agentic-kit.files → $ARTEFACTS_DIR_NAME/.agentic-kit.files"
  fi
}

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

# Hash an arbitrary string (used for tracking managed include blocks).
kit_sha256_string() {
  local s="$1"
  if command -v sha256sum &>/dev/null; then
    printf '%s' "$s" | sha256sum | awk '{print $1}'
  elif command -v shasum &>/dev/null; then
    printf '%s' "$s" | shasum -a 256 | awk '{print $1}'
  else
    err "Neither sha256sum nor shasum found — install coreutils."
    return 1
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

# ---------------------------------------------------------------------------
# Managed include blocks (CLAUDE.md / AGENTS.md / copilot-instructions.md)
#
# Strategy: instead of overwriting (or even creating from scratch) full pipeline
# documents at the project root, we maintain a small, clearly-marked block inside
# the IDE's entry-point file. The block points at .akt/PIPELINE.md
# (the canonical, kit-refreshable copy). Existing user content in the entry-point
# file is preserved verbatim; teardown.sh strips only the marked block.
# ---------------------------------------------------------------------------

# Build the include block. Args:
#   $1 — relative path to the canonical pipeline file (e.g. .akt/PIPELINE.md)
# The same block is written to CLAUDE.md and AGENTS.md; the embedded comment
# names agentic-kit so the source of truth is obvious to any reader.
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
> Project-specific config: [\`$ARTEFACTS_DIR_NAME/PROJECT.md\`]($ARTEFACTS_DIR_NAME/PROJECT.md).

@$pipeline_rel
$AGENTIC_BLOCK_END
EOF
}

# True (0) when $file already contains a kit-managed include block.
agentic_block_present() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qF "$AGENTIC_BLOCK_BEGIN" "$file" 2>/dev/null
}

# Strip the kit-managed include block from $file (idempotent). Also collapses
# the blank lines around it so we don't leave gaping holes. Echoes a status to
# stderr; returns 0 if a block was removed, 1 if no block was present, 2 on error.
agentic_block_strip() {
  local file="$1"
  [ -f "$file" ] || return 1
  agentic_block_present "$file" || return 1

  local tmp
  tmp=$(mktemp "${file}.agentic.XXXXXX") || return 2

  awk -v b="$AGENTIC_BLOCK_BEGIN" -v e="$AGENTIC_BLOCK_END" '
    BEGIN { skip=0 }
    {
      if (skip == 0 && index($0, b) > 0) { skip=1; next }
      if (skip == 1) {
        if (index($0, e) > 0) { skip=2; next }
        next
      }
      # Drop a single blank line immediately after the closing marker so the
      # surrounding document keeps its original cadence.
      if (skip == 2) { skip=3; if ($0 == "") next }
      print
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 2; }

  # Trim trailing blank lines that may now be stranded at EOF.
  local trimmed
  trimmed=$(mktemp "${file}.agentic.XXXXXX") || { rm -f "$tmp"; return 2; }
  awk '
    { lines[NR]=$0 }
    END {
      n=NR
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      for (i=1; i<=n; i++) print lines[i]
    }
  ' "$tmp" > "$trimmed" || { rm -f "$tmp" "$trimmed"; return 2; }
  mv "$trimmed" "$file"
  rm -f "$tmp"
  return 0
}

# Write a fresh "stub" entry-point file (used when no CLAUDE.md / AGENTS.md
# exists yet). We put the include block at the top so the user's later edits
# accumulate naturally below it.
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

# Append the include block to an existing user-owned entry-point file. We add a
# leading blank line if the existing file does not already end with one, so the
# diff is small and reviewable.
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
# Same idea as the include block above but for .gitignore. We never touch the
# user's existing entries; we maintain a single clearly-marked block at the end
# of the file. Teardown removes the block; everything outside it is preserved.

# Args: $1 — relative path to .gitignore (typically "$PROJECT_ROOT/.gitignore")
agentic_gitignore_render() {
  cat <<EOF
$AGENTIC_GITIGNORE_BEGIN
# Managed by agentic-kit. Re-run \`agentic-kit/init.sh\` to refresh, or
# \`agentic-kit/teardown.sh\` to remove the whole block. Edits inside this block
# are overwritten on init.
#
# --- Runtime / ephemeral (pipeline scratch; usually not committed) ---
$ARTEFACTS_DIR_NAME/memory/
$ARTEFACTS_DIR_NAME/features/
$ARTEFACTS_DIR_NAME/archive/
$ARTEFACTS_DIR_NAME/proposed-patches/
$ARTEFACTS_DIR_NAME/scratch/
$ARTEFACTS_DIR_NAME/SESSION-STATE.md
$ARTEFACTS_DIR_NAME/MEMORY.md
$ARTEFACTS_DIR_NAME/PROJECT_PROFILE.md
#
# --- Per-machine kit bookkeeping (usually not committed) ---
$ARTEFACTS_DIR_NAME/.agentic-kit.cfg
$ARTEFACTS_DIR_NAME/.agentic-kit.files
#
# Optional — ignore all of $ARTEFACTS_DIR_NAME/ except PIPELINE.md + PROJECT.md (uncomment all 4 lines):
# $ARTEFACTS_DIR_NAME/**
# !$ARTEFACTS_DIR_NAME/
# !$ARTEFACTS_DIR_NAME/PIPELINE.md
# !$ARTEFACTS_DIR_NAME/PROJECT.md
#
$AGENTIC_GITIGNORE_END
EOF
}

agentic_gitignore_present() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -qF "$AGENTIC_GITIGNORE_BEGIN" "$file" 2>/dev/null
}

agentic_gitignore_strip() {
  local file="$1"
  [ -f "$file" ] || return 1
  agentic_gitignore_present "$file" || return 1
  local tmp
  tmp=$(mktemp "${file}.agentic.XXXXXX") || return 2
  awk -v b="$AGENTIC_GITIGNORE_BEGIN" -v e="$AGENTIC_GITIGNORE_END" '
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
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 2; }
  local trimmed
  trimmed=$(mktemp "${file}.agentic.XXXXXX") || { rm -f "$tmp"; return 2; }
  awk '
    { lines[NR]=$0 }
    END {
      n=NR
      while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
      for (i=1; i<=n; i++) print lines[i]
    }
  ' "$tmp" > "$trimmed" || { rm -f "$tmp" "$trimmed"; return 2; }
  mv "$trimmed" "$file"
  rm -f "$tmp"
  return 0
}

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
