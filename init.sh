#!/usr/bin/env bash
# Run from the target project root after adding the submodule.
# Usage: .agentic-kit/init.sh [--force | --skip]
#
# Creates symlinks from .claude/agents/ and .claude/skills/ into the submodule,
# copies CLAUDE.md and PROJECT.md templates, and updates .gitignore.
#
# Flags:
#   --force   Overwrite all existing files without prompting
#   --skip    Skip all existing files without prompting (default non-interactive)

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
success() { printf "  ${GREEN}+${RESET} %s\n" "$*"; }
skip()    { printf "  ${YELLOW}skip${RESET} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
err()     { printf "  ${RED}error${RESET} %s\n" "$*"; }
header()  { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }

# Prompt: [s]kip  [o]verwrite  [a]ll
# Sets CONFLICT_CHOICE. Returns 0 if overwrite, 1 if skip.
OVERWRITE_ALL=false
ask_conflict() {
  local label="$1"
  if $OVERWRITE_ALL; then return 0; fi
  if [ ! -t 0 ]; then return 1; fi  # non-interactive → skip
  while true; do
    printf "  ${YELLOW}exists${RESET} %s — " "$label"
    printf "[${BOLD}s${RESET}]kip  [${BOLD}o${RESET}]verwrite  [${BOLD}a${RESET}]ll  "
    read -r -n1 choice; echo
    case "$choice" in
      o|O) return 0 ;;
      a|A) OVERWRITE_ALL=true; return 0 ;;
      s|S|"") return 1 ;;
      *) ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
MODE=""
for arg in "$@"; do
  case "$arg" in
    --force) MODE="force" ;;
    --skip)  MODE="skip" ;;
  esac
done

if [ "$MODE" = "force" ]; then OVERWRITE_ALL=true; fi

# Resolve: should we overwrite this item?
# Returns 0 = overwrite, 1 = skip
should_overwrite() {
  local label="$1"
  if [ "$MODE" = "skip" ]; then
    skip "$label (use --force to overwrite)"
    return 1
  fi
  ask_conflict "$label"
}

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")

printf "\n${BOLD}${CYAN}  agentic-kit${RESET}\n"
info "project root: $PROJECT_ROOT"
info "kit location: $SUBMODULE_DIR/"

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------
header "Agents"
mkdir -p "$PROJECT_ROOT/.claude/agents"

for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  target="$PROJECT_ROOT/.claude/agents/$name"
  link="../../$SUBMODULE_DIR/agents/$name"

  if [ -e "$target" ] || [ -L "$target" ]; then
    if should_overwrite ".claude/agents/$name"; then
      rm -f "$target"
      ln -s "$link" "$target"
      success ".claude/agents/$name (overwritten)"
    fi
  else
    ln -s "$link" "$target"
    success ".claude/agents/$name"
  fi
done

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
header "Skills"
mkdir -p "$PROJECT_ROOT/.claude/skills"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  target="$PROJECT_ROOT/.claude/skills/$name"
  link="../../$SUBMODULE_DIR/skills/$name"

  if [ -e "$target" ] || [ -L "$target" ]; then
    if should_overwrite ".claude/skills/$name"; then
      rm -rf "$target"
      ln -s "$link" "$target"
      success ".claude/skills/$name (overwritten)"
    fi
  else
    ln -s "$link" "$target"
    success ".claude/skills/$name"
  fi
done

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
header "Tools"
TOOLS_TARGET="$PROJECT_ROOT/tools"

if [ -e "$TOOLS_TARGET" ] || [ -L "$TOOLS_TARGET" ]; then
  if should_overwrite "tools/"; then
    rm -rf "$TOOLS_TARGET"
    ln -s "$SUBMODULE_DIR/tools" "$TOOLS_TARGET"
    success "tools/ (overwritten)"
  fi
else
  ln -s "$SUBMODULE_DIR/tools" "$TOOLS_TARGET"
  success "tools/"
fi

# ---------------------------------------------------------------------------
# CLAUDE.md
# ---------------------------------------------------------------------------
header "Configuration"

if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  if should_overwrite "CLAUDE.md"; then
    cp "$SCRIPT_DIR/CLAUDE.md.template" "$PROJECT_ROOT/CLAUDE.md"
    success "CLAUDE.md (overwritten from template)"
  fi
else
  cp "$SCRIPT_DIR/CLAUDE.md.template" "$PROJECT_ROOT/CLAUDE.md"
  success "CLAUDE.md"
fi

# ---------------------------------------------------------------------------
# PROJECT.md
# ---------------------------------------------------------------------------
if [ -f "$PROJECT_ROOT/PROJECT.md" ]; then
  if should_overwrite "PROJECT.md"; then
    cp "$SCRIPT_DIR/PROJECT.md.template" "$PROJECT_ROOT/PROJECT.md"
    success "PROJECT.md (overwritten from template)"
  fi
else
  cp "$SCRIPT_DIR/PROJECT.md.template" "$PROJECT_ROOT/PROJECT.md"
  success "PROJECT.md"

  if command -v claude &>/dev/null && [ -t 0 ]; then
    echo ""
    printf "  Fill in ${BOLD}PROJECT.md${RESET} automatically using Claude? [${BOLD}Y${RESET}/n] "
    read -r yn; yn="${yn:-Y}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      info "Running Claude..."
      cd "$PROJECT_ROOT"
      claude -p --allowedTools 'Edit,Write,Read,Glob,Grep,Bash' "Inspect this project's files (e.g. package.json, pyproject.toml, \
Makefile, Cargo.toml, go.mod — whatever exists) to infer the test command, build \
command, and any version files. Then fill in all the placeholder values in PROJECT.md \
and write the completed file. Only ask me if you genuinely cannot determine a value."
      success "PROJECT.md filled in"
      info "Run ${SUBMODULE_DIR}/tools/validate-config.sh to verify."
    else
      info "Edit PROJECT.md manually, then run: ${SUBMODULE_DIR}/tools/validate-config.sh"
    fi
  else
    info "Edit PROJECT.md → Project-Specific Configuration, then run:"
    info "${SUBMODULE_DIR}/tools/validate-config.sh"
  fi
fi

# ---------------------------------------------------------------------------
# .gitignore
# ---------------------------------------------------------------------------
header ".gitignore"
GITIGNORE="$PROJECT_ROOT/.gitignore"

for entry in ".artefacts/"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
    success ".gitignore ← $entry"
  else
    info "$entry already in .gitignore"
  fi
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  Done.${RESET} Agents and skills symlinked into .claude/\n"
info "Start a feature with /vadavik in Claude Code"
echo ""
