#!/usr/bin/env bash
# Run from the target project root after adding the submodule.
# Usage: .agentic-kit/init.sh
#
# Creates symlinks from .claude/agents/ and .claude/skills/ into the submodule,
# copies CLAUDE.md template if none exists, and updates .gitignore.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")   # e.g. ".agentic-kit"

echo "agentic-kit: initializing from $SCRIPT_DIR"
echo "  → project root: $PROJECT_ROOT"

# ---------------------------------------------------------------------------
# Create .claude dirs
# ---------------------------------------------------------------------------
mkdir -p "$PROJECT_ROOT/.claude/agents"
mkdir -p "$PROJECT_ROOT/.claude/skills"

# ---------------------------------------------------------------------------
# Symlink agents
# Relative path from .claude/agents/ to submodule agents/ is always
# ../../<submodule-dir>/agents/ — no realpath needed, fully portable.
# ---------------------------------------------------------------------------
for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  target="$PROJECT_ROOT/.claude/agents/$name"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "  SKIP agents/$name (already exists)"
    continue
  fi
  ln -s "../../$SUBMODULE_DIR/agents/$name" "$target"
  echo "  + .claude/agents/$name"
done

# ---------------------------------------------------------------------------
# Symlink skill directories
# Relative path from .claude/skills/ to submodule skills/<name>/ is always
# ../../<submodule-dir>/skills/<name>/ — no realpath needed, fully portable.
# ---------------------------------------------------------------------------
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$PROJECT_ROOT/.claude/skills/$name"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "  SKIP skills/$name (already exists)"
    continue
  fi
  ln -s "../../$SUBMODULE_DIR/skills/$name" "$target"
  echo "  + .claude/skills/$name"
done

# ---------------------------------------------------------------------------
# Copy CLAUDE.md template (only if none exists)
# ---------------------------------------------------------------------------
if [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  cp "$SCRIPT_DIR/CLAUDE.md.template" "$PROJECT_ROOT/CLAUDE.md"
  echo "  + CLAUDE.md created — edit the Project-Specific Configuration section."
else
  echo "  SKIP CLAUDE.md (already exists — manually merge from $SUBMODULE_DIR/CLAUDE.md.template if needed)"
fi

# ---------------------------------------------------------------------------
# Update target project's .gitignore
# ---------------------------------------------------------------------------
GITIGNORE="$PROJECT_ROOT/.gitignore"
for entry in "$SUBMODULE_DIR" ".artefacts/"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
    echo "  + .gitignore ← $entry"
  fi
done

echo ""
echo "Done. Agents and skills symlinked into .claude/"
echo "Next: edit CLAUDE.md → Project-Specific Configuration, then run:"
echo "  $SUBMODULE_DIR/tools/validate-config.sh"
