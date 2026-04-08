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
# Symlink tools/ directory
# Relative path from project root to submodule tools/ is <submodule-dir>/tools/
# ---------------------------------------------------------------------------
TOOLS_TARGET="$PROJECT_ROOT/tools"
if [ -e "$TOOLS_TARGET" ] || [ -L "$TOOLS_TARGET" ]; then
  echo "  SKIP tools/ (already exists — if not a kit symlink, agents may need manual path adjustment)"
else
  ln -s "$SUBMODULE_DIR/tools" "$TOOLS_TARGET"
  echo "  + tools/"
fi

# ---------------------------------------------------------------------------
# Copy CLAUDE.md template (only if none exists)
# ---------------------------------------------------------------------------
if [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  cp "$SCRIPT_DIR/CLAUDE.md.template" "$PROJECT_ROOT/CLAUDE.md"
  echo "  + CLAUDE.md created"
else
  echo "  SKIP CLAUDE.md (already exists — manually merge from $SUBMODULE_DIR/CLAUDE.md.template if needed)"
fi

# ---------------------------------------------------------------------------
# Copy PROJECT.md template (only if none exists), optionally fill via Claude
# ---------------------------------------------------------------------------
if [ ! -f "$PROJECT_ROOT/PROJECT.md" ]; then
  cp "$SCRIPT_DIR/PROJECT.md.template" "$PROJECT_ROOT/PROJECT.md"
  echo "  + PROJECT.md created"

  if command -v claude &>/dev/null; then
    echo ""
    read -r -p "  Use Claude to fill in PROJECT.md automatically? [Y/n] " yn
    yn="${yn:-Y}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      echo "  Running Claude..."
      cd "$PROJECT_ROOT"
      claude -p --allowedTools 'Edit,Write,Read,Glob,Grep,Bash' "Inspect this project's files (e.g. package.json, pyproject.toml, \
Makefile, Cargo.toml, go.mod — whatever exists) to infer the test command, build \
command, and any version files. Then fill in all the placeholder values in PROJECT.md \
and write the completed file. Only ask me if you genuinely cannot determine a value."
      echo "  PROJECT.md filled in. Run $SUBMODULE_DIR/tools/validate-config.sh to verify."
    else
      echo "  Edit PROJECT.md manually, then run: $SUBMODULE_DIR/tools/validate-config.sh"
    fi
  else
    echo "  Edit PROJECT.md → Project-Specific Configuration, then run:"
    echo "  $SUBMODULE_DIR/tools/validate-config.sh"
  fi
else
  echo "  SKIP PROJECT.md (already exists)"
fi

# ---------------------------------------------------------------------------
# Update target project's .gitignore
# ---------------------------------------------------------------------------
GITIGNORE="$PROJECT_ROOT/.gitignore"
for entry in ".artefacts/"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
    echo "  + .gitignore ← $entry"
  fi
done

echo ""
echo "Done. Agents and skills symlinked into .claude/"
