#!/usr/bin/env bash
# Removes agentic-kit symlinks from .claude/ in the target project.
# Usage: .agentic-kit/teardown.sh [--remove-submodule]
# Run from the project root (parent of the submodule directory).

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & helpers
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

info()    { printf "  ${DIM}%s${RESET}\n" "$*"; }
removed() { printf "  ${RED}-${RESET} %s\n" "$*"; }
skip()    { printf "  ${YELLOW}skip${RESET} %s %s\n" "$1" "${2:-}"; }
header()  { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")

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
    skip ".claude/agents/$name" "(local override — delete manually)"
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
    skip ".claude/skills/$name" "(local override — delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove tools/ symlink
# ---------------------------------------------------------------------------
header "Tools"
TOOLS_TARGET="$PROJECT_ROOT/tools"

if [ -L "$TOOLS_TARGET" ]; then
  rm "$TOOLS_TARGET"
  removed "tools/"
elif [ -e "$TOOLS_TARGET" ]; then
  skip "tools/" "(not a symlink — delete manually)"
else
  info "tools/ not present"
fi

# ---------------------------------------------------------------------------
# Clean .gitignore entries
# ---------------------------------------------------------------------------
header ".gitignore"
GITIGNORE="$PROJECT_ROOT/.gitignore"

if [ -f "$GITIGNORE" ]; then
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
info "CLAUDE.md and PROJECT.md kept — edit or delete manually."
if [[ "${1:-}" != "--remove-submodule" ]]; then
  info "To also remove the submodule: $SUBMODULE_DIR/teardown.sh --remove-submodule"
fi
echo ""
