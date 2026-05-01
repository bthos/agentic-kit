#!/usr/bin/env bash
# Removes agentic-kit installed copies from .claude/ / .cursor/ / .github/ in the target project.
# Uses .agentic-kit.files (SHA-256) to avoid deleting user-modified files.
# Usage: agentic-kit/teardown.sh [--remove-submodule] [--full-clean] [--yes] [--dry-run]
#   --full-clean   Also offer to remove CLAUDE.md and PROJECT.md
#   --yes, -y      Skip all confirmation prompts (auto-confirm)
#   --dry-run      Show what would be removed without doing it
# Run from the project root (parent of the submodule directory).

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# ---------------------------------------------------------------------------
# Flag parsing (must come before any removal logic)
# ---------------------------------------------------------------------------
REMOVE_SUBMODULE=false
FULL_CLEAN=false
YES=false
DRY_RUN=false
for _arg in "$@"; do
  case "$_arg" in
    --remove-submodule) REMOVE_SUBMODULE=true ;;
    --full-clean)       FULL_CLEAN=true ;;
    --yes|-y)           YES=true ;;
    --dry-run)          DRY_RUN=true ;;
  esac
done
# Non-interactive (no TTY) auto-enables --yes
[ ! -t 0 ] && YES=true

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
printf "${BOLD}${CYAN}  │    agentic-kit teardown     │${RESET}\n"
printf "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
info "project root: $PROJECT_ROOT"
$DRY_RUN && warn "Dry run — no files will be removed."

# ---------------------------------------------------------------------------
# Dry-run-aware removal helpers
# ---------------------------------------------------------------------------
do_rm() {
  if $DRY_RUN; then
    info "would remove: $1"
  else
    rm "$1"
  fi
}
do_rm_rf() {
  if $DRY_RUN; then
    info "would remove: $1"
  else
    rm -rf "$1"
  fi
}

_manifest_drop() {
  if ! $DRY_RUN; then manifest_remove_entry "$1"; fi
}

# Remove a regular file if manifest hash matches (or legacy kit marker + no manifest).
teardown_managed_file() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    do_rm "$abs"
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
    do_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && grep -qF "$AGENTIC_MARKER" "$abs" 2>/dev/null; then
    do_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy kit marker, no manifest)"
    return 0
  fi

  skip "$rel (modified or unknown — hash mismatch or not kit-managed)"
}

# Remove a copied skill tree if manifest hash matches (or matches live kit source).
teardown_managed_tree() {
  local rel="$1"
  local kit_src="$2"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have want

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    do_rm_rf "$abs"
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
    do_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && [ -d "$kit_src" ]; then
    want=$(kit_sha256_tree "$kit_src") || true
    if [ -n "$want" ] && [ -n "$have" ] && [ "$have" = "$want" ]; then
      do_rm_rf "$abs"
      _manifest_drop "$rel"
      removed "$rel (matches kit source, no manifest)"
      return 0
    fi
  fi

  skip "$rel (modified locally — hash mismatch)"
}

# ---------------------------------------------------------------------------
# Remove Claude agents (copies)
# ---------------------------------------------------------------------------
header "Agents"

for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  teardown_managed_file ".claude/agents/$name"
done

# ---------------------------------------------------------------------------
# Remove Claude skill copies
# ---------------------------------------------------------------------------
header "Skills"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  teardown_managed_tree ".claude/skills/$name" "${skill_dir%/}"
done

# ---------------------------------------------------------------------------
# Remove Cursor skill copies, subagents, legacy rules, AGENTS.md
# ---------------------------------------------------------------------------
header "Cursor"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  teardown_managed_tree ".cursor/skills/$name" "${skill_dir%/}"
done
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/skills" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/skills" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.cursor/skills" 2>/dev/null && removed ".cursor/skills/ (empty dir)" || true
fi

if [ -d "$PROJECT_ROOT/.cursor/agents" ]; then
  for sf in "$PROJECT_ROOT/.cursor/agents/"*.md; do
    [ -e "$sf" ] || continue
    teardown_managed_file ".cursor/agents/$(basename "$sf")"
  done
  if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/agents" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/agents" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/agents" 2>/dev/null && removed ".cursor/agents/ (empty dir)" || true
  fi
else
  info ".cursor/agents/ not present"
fi

if [ -d "$PROJECT_ROOT/.cursor/rules" ]; then
  for mdc in "$PROJECT_ROOT/.cursor/rules/"*.mdc; do
    [ -e "$mdc" ] || continue
    teardown_managed_file ".cursor/rules/$(basename "$mdc")"
  done
  if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/rules" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/rules" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/rules" 2>/dev/null && removed ".cursor/rules/ (empty dir)" || true
  fi
else
  info ".cursor/rules/ not present"
fi

teardown_managed_file "AGENTS.md"

# ---------------------------------------------------------------------------
# Remove GitHub Copilot generated files
# ---------------------------------------------------------------------------
header "GitHub Copilot"

GITHUB_DIR="$PROJECT_ROOT/.github"

if [ -d "$GITHUB_DIR/agents" ]; then
  for f in "$GITHUB_DIR/agents/"*.agent.md; do
    [ -e "$f" ] || continue
    teardown_managed_file ".github/agents/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    [ -z "$(ls -A "$GITHUB_DIR/agents" 2>/dev/null)" ] && rmdir "$GITHUB_DIR/agents" 2>/dev/null && removed ".github/agents/ (empty dir)" || true
  fi
else
  info ".github/agents/ not present"
fi

if [ -d "$GITHUB_DIR/instructions" ]; then
  for f in "$GITHUB_DIR/instructions/"*.instructions.md; do
    [ -e "$f" ] || continue
    teardown_managed_file ".github/instructions/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    [ -z "$(ls -A "$GITHUB_DIR/instructions" 2>/dev/null)" ] && rmdir "$GITHUB_DIR/instructions" 2>/dev/null && removed ".github/instructions/ (empty dir)" || true
  fi
else
  info ".github/instructions/ not present"
fi

CI_FILE="$GITHUB_DIR/copilot-instructions.md"
if [ -f "$CI_FILE" ]; then
  teardown_managed_file ".github/copilot-instructions.md"
else
  _manifest_drop ".github/copilot-instructions.md"
  info ".github/copilot-instructions.md not present"
fi

# ---------------------------------------------------------------------------
# Optionally remove the submodule
# ---------------------------------------------------------------------------
if $REMOVE_SUBMODULE && ! $DRY_RUN; then
  header "Submodule"
  cd "$PROJECT_ROOT"
  git submodule deinit -f "$SUBMODULE_DIR" 2>/dev/null || true
  git rm -f "$SUBMODULE_DIR" 2>/dev/null || true
  do_rm_rf ".git/modules/$SUBMODULE_DIR"
  removed "submodule $SUBMODULE_DIR"
elif $REMOVE_SUBMODULE && $DRY_RUN; then
  header "Submodule"
  info "would deinit and remove submodule $SUBMODULE_DIR"
fi

# ---------------------------------------------------------------------------
# Optionally remove CLAUDE.md and PROJECT.md (--full-clean)
# ---------------------------------------------------------------------------
if $FULL_CLEAN; then
  header "Full clean — CLAUDE.md and PROJECT.md"
  _confirm_remove() {
    local file="$1"
    if [ ! -f "$PROJECT_ROOT/$file" ]; then
      info "$file not present"
      return
    fi
    if $DRY_RUN; then
      info "would remove: $file"
      return
    fi
    if $YES; then
      rm "$PROJECT_ROOT/$file"
      removed "$file"
      return
    fi
    local _yn
    if [ -t 0 ]; then
      printf "  ${YELLOW}⚠${RESET} Remove ${BOLD}%s${RESET}? [y/N] " "$file"
      read -r -n1 _yn; printf '\n'
    elif { : >/dev/tty; } 2>/dev/null; then
      printf "  ${YELLOW}⚠${RESET} Remove ${BOLD}%s${RESET}? [y/N] " "$file" >/dev/tty
      read -r _yn </dev/tty
    else
      info "$file kept (no TTY — use --yes to remove, or delete manually)"
      return
    fi
    if [[ "${_yn:-N}" =~ ^[Yy]$ ]]; then
      rm "$PROJECT_ROOT/$file"
      removed "$file"
    else
      skip "$file (kept)"
    fi
  }
  _confirm_remove "CLAUDE.md"
  _confirm_remove "PROJECT.md"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  ✓ Done.${RESET}\n"
if ! $FULL_CLEAN; then
  info "CLAUDE.md and PROJECT.md kept — use --full-clean to remove them."
fi
if ! $REMOVE_SUBMODULE; then
  info "Submodule kept — use --remove-submodule to deinit."
fi
$DRY_RUN && warn "Dry run complete — rerun without --dry-run to apply."
printf '\n'
