#!/usr/bin/env bash
# Removes agentic-kit symlinks from .claude/ in the target project.
# Usage: .agentic-kit/teardown.sh [--remove-submodule]
# Run from the project root (parent of the submodule directory).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")

echo "agentic-kit: tearing down from $PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Remove agent symlinks
# ---------------------------------------------------------------------------
for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  target="$PROJECT_ROOT/.claude/agents/$name"
  if [ -L "$target" ]; then
    rm "$target"
    echo "  - .claude/agents/$name"
  elif [ -e "$target" ]; then
    echo "  SKIP .claude/agents/$name (not a symlink — may be a local override; delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove skill symlinks
# ---------------------------------------------------------------------------
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$PROJECT_ROOT/.claude/skills/$name"
  if [ -L "$target" ]; then
    rm "$target"
    echo "  - .claude/skills/$name"
  elif [ -e "$target" ]; then
    echo "  SKIP .claude/skills/$name (not a symlink — may be a local override; delete manually)"
  fi
done

# ---------------------------------------------------------------------------
# Remove tools/ symlink
# ---------------------------------------------------------------------------
TOOLS_TARGET="$PROJECT_ROOT/tools"
if [ -L "$TOOLS_TARGET" ]; then
  rm "$TOOLS_TARGET"
  echo "  - tools/"
elif [ -e "$TOOLS_TARGET" ]; then
  echo "  SKIP tools/ (not a symlink — delete manually if it was added by agentic-kit)"
fi

# ---------------------------------------------------------------------------
# Clean .gitignore entries
# ---------------------------------------------------------------------------
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
  for entry in "$SUBMODULE_DIR" ".artefacts/"; do
    if grep -qxF "$entry" "$GITIGNORE" 2>/dev/null; then
      # Portable in-place removal without temp file race
      grep -v "^${entry}\$" "$GITIGNORE" > "${GITIGNORE}.tmp" && mv "${GITIGNORE}.tmp" "$GITIGNORE"
      echo "  - .gitignore: removed '$entry'"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Optionally remove the submodule
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--remove-submodule" ]]; then
  echo ""
  echo "Removing git submodule..."
  cd "$PROJECT_ROOT"
  git submodule deinit -f "$SUBMODULE_DIR"
  git rm -f "$SUBMODULE_DIR"
  rm -rf ".git/modules/$SUBMODULE_DIR"
  echo "  - submodule removed"
fi

echo ""
echo "Done. CLAUDE.md kept — edit or delete manually."
if [[ "${1:-}" != "--remove-submodule" ]]; then
  echo "To also remove the submodule: $SUBMODULE_DIR/teardown.sh --remove-submodule"
fi
