#!/usr/bin/env bash
# Removes agentic-kit symlinks from .claude/ in the target project.
# Usage: .agentic-kit/teardown.sh [--remove-submodule] [--full-clean] [--yes] [--dry-run]
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

# ---------------------------------------------------------------------------
# Remove agent symlinks
# ---------------------------------------------------------------------------
header "Agents"

for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  target="$PROJECT_ROOT/.claude/agents/$name"
  if [ -L "$target" ]; then
    do_rm "$target"
    removed ".claude/agents/$name"
  elif [ -e "$target" ]; then
    skip ".claude/agents/$name (local override — delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove skill symlinks
# ---------------------------------------------------------------------------
header "Skills"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$PROJECT_ROOT/.claude/skills/$name"
  if [ -L "$target" ]; then
    do_rm "$target"
    removed ".claude/skills/$name"
  elif [ -e "$target" ]; then
    skip ".claude/skills/$name (local override — delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove Cursor skills symlinks, generated rules, and AGENTS.md
# ---------------------------------------------------------------------------
header "Cursor"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$PROJECT_ROOT/.cursor/skills/$name"
  if [ -L "$target" ]; then
    do_rm "$target"
    removed ".cursor/skills/$name"
  elif [ -e "$target" ]; then
    skip ".cursor/skills/$name (local override — delete manually)"
  fi
done
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/skills" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/skills" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.cursor/skills" 2>/dev/null && removed ".cursor/skills/ (empty dir)" || true
fi

if [ -d "$PROJECT_ROOT/.cursor/rules" ]; then
  for mdc in "$PROJECT_ROOT/.cursor/rules/"*.mdc; do
    [ -e "$mdc" ] || continue
    if grep -qF "$AGENTIC_MARKER" "$mdc" 2>/dev/null; then
      do_rm "$mdc"
      removed ".cursor/rules/$(basename "$mdc")"
    else
      skip ".cursor/rules/$(basename "$mdc") (not kit-managed)"
    fi
  done
  if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/rules" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/rules" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/rules" 2>/dev/null && removed ".cursor/rules/ (empty dir)" || true
  fi
else
  info ".cursor/rules/ not present"
fi

AGENTS="$PROJECT_ROOT/AGENTS.md"
if [ -f "$AGENTS" ]; then
  if grep -qF "$AGENTIC_MARKER" "$AGENTS" 2>/dev/null; then
    do_rm "$AGENTS"
    removed "AGENTS.md"
  else
    skip "AGENTS.md (not kit-managed)"
  fi
else
  info "AGENTS.md not present"
fi

# ---------------------------------------------------------------------------
# Remove GitHub Copilot generated files
# ---------------------------------------------------------------------------
header "GitHub Copilot"

GITHUB_DIR="$PROJECT_ROOT/.github"

if [ -d "$GITHUB_DIR/agents" ]; then
  for f in "$GITHUB_DIR/agents/"*.agent.md; do
    [ -e "$f" ] || continue
    if grep -qF "$AGENTIC_MARKER" "$f" 2>/dev/null; then
      do_rm "$f"
      removed ".github/agents/$(basename "$f")"
    else
      skip ".github/agents/$(basename "$f") (not kit-managed)"
    fi
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
    if grep -qF "$AGENTIC_MARKER" "$f" 2>/dev/null; then
      do_rm "$f"
      removed ".github/instructions/$(basename "$f")"
    else
      skip ".github/instructions/$(basename "$f") (not kit-managed)"
    fi
  done
  if ! $DRY_RUN; then
    [ -z "$(ls -A "$GITHUB_DIR/instructions" 2>/dev/null)" ] && rmdir "$GITHUB_DIR/instructions" 2>/dev/null && removed ".github/instructions/ (empty dir)" || true
  fi
else
  info ".github/instructions/ not present"
fi

CI_FILE="$GITHUB_DIR/copilot-instructions.md"
if [ -f "$CI_FILE" ]; then
  if grep -qF "$AGENTIC_MARKER" "$CI_FILE" 2>/dev/null; then
    do_rm "$CI_FILE"
    removed ".github/copilot-instructions.md"
  else
    skip ".github/copilot-instructions.md (not kit-managed)"
  fi
else
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
