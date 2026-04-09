#!/usr/bin/env bash
# Removes agentic-kit symlinks from .claude/ in the target project.
# Usage: .agentic-kit/teardown.sh [--remove-submodule]
# Run from the project root (parent of the submodule directory).

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

printf "\n${BOLD}${CYAN}  agentic-kit${RESET} ${DIM}teardown${RESET}\n"
info "project root: $PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Remove agent symlinks
# ---------------------------------------------------------------------------
header "Agents"

for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  target="$PROJECT_ROOT/.claude/agents/$name"
  if [ -L "$target" ]; then
    rm "$target"
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
    rm "$target"
    removed ".claude/skills/$name"
  elif [ -e "$target" ]; then
    skip ".claude/skills/$name (local override — delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove Cursor-generated rules and AGENTS.md
# ---------------------------------------------------------------------------
header "Cursor"

if [ -d "$PROJECT_ROOT/.cursor/rules" ]; then
  for mdc in "$PROJECT_ROOT/.cursor/rules/"*.mdc; do
    [ -e "$mdc" ] || continue
    if grep -qF "$AGENTIC_MARKER" "$mdc" 2>/dev/null; then
      rm "$mdc"
      removed ".cursor/rules/$(basename "$mdc")"
    else
      skip ".cursor/rules/$(basename "$mdc") (not kit-managed)"
    fi
  done
  if [ -d "$PROJECT_ROOT/.cursor/rules" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/rules" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/rules" 2>/dev/null && removed ".cursor/rules/ (empty dir)" || true
  fi
else
  info ".cursor/rules/ not present"
fi

AGENTS="$PROJECT_ROOT/AGENTS.md"
if [ -f "$AGENTS" ]; then
  if grep -qF "$AGENTIC_MARKER" "$AGENTS" 2>/dev/null; then
    rm "$AGENTS"
    removed "AGENTS.md"
  else
    skip "AGENTS.md (not kit-managed)"
  fi
else
  info "AGENTS.md not present"
fi

# ---------------------------------------------------------------------------
# Remove tools/ symlink
# ---------------------------------------------------------------------------
header "Tools"
TOOLS_TARGET="$PROJECT_ROOT/tools"

if [ -L "$TOOLS_TARGET" ]; then
  rm "$TOOLS_TARGET"
  removed "tools/"
elif [ -e "$TOOLS_TARGET" ]; then
  skip "tools/ (not a symlink — delete manually)"
else
  info "tools/ not present"
fi

# ---------------------------------------------------------------------------
# Clean .gitignore entries
# ---------------------------------------------------------------------------
header ".gitignore"
GITIGNORE="$PROJECT_ROOT/.gitignore"

if [ -f "$GITIGNORE" ]; then
  # Extend this list when init.sh adds more managed ignore entries.
  for entry in ".artefacts/"; do
    if grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
      grep -v "^${entry}\$" "$GITIGNORE" > "${GITIGNORE}.tmp" && mv "${GITIGNORE}.tmp" "$GITIGNORE"
      removed ".gitignore: $entry"
    fi
  done
else
  info ".gitignore not found"
fi

# ---------------------------------------------------------------------------
# Optionally remove the submodule
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--remove-submodule" ]]; then
  header "Submodule"
  cd "$PROJECT_ROOT"
  git submodule deinit -f "$SUBMODULE_DIR" 2>/dev/null || true
  git rm -f "$SUBMODULE_DIR" 2>/dev/null || true
  rm -rf ".git/modules/$SUBMODULE_DIR"
  removed "submodule $SUBMODULE_DIR"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  Done.${RESET} "
info "CLAUDE.md and PROJECT.md kept — edit or delete manually (AGENTS.md removed if kit-managed)."
if [[ "${1:-}" != "--remove-submodule" ]]; then
  info "To also remove the submodule: $SUBMODULE_DIR/teardown.sh --remove-submodule"
fi
printf '\n'