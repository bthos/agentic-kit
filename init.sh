#!/usr/bin/env bash
# Run from the target project root after adding the submodule.
# Usage: .agentic-kit/init.sh [--force | --overwrite-all | --skip | --skip-all] [--ide=claude|cursor|both]
# Env: IDE_CHOICE=claude|cursor|both (same as --ide, for non-interactive)
#
# Creates symlinks for Claude Code (.claude/) and/or generates Cursor rules (.cursor/rules/*.mdc),
# copies PIPELINE.md.template → CLAUDE.md and/or AGENTS.md, PROJECT.md template, symlinks tools/, updates .gitignore.
#
# Flags:
#   --force, --overwrite-all   Overwrite all existing kit-managed paths without prompting
#   --skip, --skip-all         Skip every existing path without prompting (non-interactive default when stdin is not a TTY)
#   --ide=X                    Target IDE: claude (default), cursor, or both (non-interactive; skips IDE prompt)
#
# Interactive conflict prompt: [s]kip this  [o]verwrite this  overwrite [a]ll  skip [r]est (this + all later conflicts)

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

# ---------------------------------------------------------------------------
# Conflict resolution (init-only)
# ---------------------------------------------------------------------------
OVERWRITE_ALL=false
SKIP_ALL=false
ask_conflict() {
  local label="$1"
  if $OVERWRITE_ALL; then return 0; fi
  if $SKIP_ALL; then return 1; fi
  if [ ! -t 0 ]; then return 1; fi
  while true; do
    printf "  ${YELLOW}exists${RESET} %s — " "$label"
    printf "[${BOLD}s${RESET}]kip  [${BOLD}o${RESET}]verwrite  overwrite ${BOLD}a${RESET}ll  skip ${BOLD}r${RESET}est  "
    read -r -n1 choice
    printf '\n'
    case "$choice" in
      o|O) return 0 ;;
      a|A) OVERWRITE_ALL=true; return 0 ;;
      r|R) SKIP_ALL=true; return 1 ;;
      s|S|"") return 1 ;;
      *) ;;
    esac
  done
}

MODE=""
IDE_CHOICE="${IDE_CHOICE:-}"

for arg in "$@"; do
  case "$arg" in
    --force|--overwrite-all) MODE="force" ;;
    --skip|--skip-all)       MODE="skip" ;;
    --ide=*)                 IDE_CHOICE="${arg#--ide=}" ;;
  esac
done

if [ -n "$IDE_CHOICE" ] && [[ ! "$IDE_CHOICE" =~ ^(claude|cursor|both)$ ]]; then
  err "Invalid --ide value '$IDE_CHOICE' (use claude, cursor, or both)"
  exit 1
fi

if [ "$MODE" = "force" ]; then OVERWRITE_ALL=true; fi

should_overwrite() {
  local label="$1"
  if [ "$MODE" = "skip" ]; then
    skip "$label (use --force or --overwrite-all to overwrite)"
    return 1
  fi
  if $SKIP_ALL; then
    skip "$label (skip rest)"
    return 1
  fi
  ask_conflict "$label"
}

# ---------------------------------------------------------------------------
# YAML / .mdc helpers (Cursor)
# ---------------------------------------------------------------------------
# Body: everything after the closing --- of YAML frontmatter
strip_frontmatter_body() {
  awk '/^---$/ { if (++c == 2) { body=1; next } } body { print }' "$1"
}

# Extract first line matching "^key:" from the first frontmatter block only
extract_yaml_field() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d' | grep -m1 "^${key}:" | sed "s/^${key}:[[:space:]]*//" | sed 's/^"\(.*\)"$/\1/'
}

escape_yaml_double() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Output .mdc basename (with .mdc suffix) from optional frontmatter cursor_rule_name, else <base>.mdc
cursor_rule_out_name() {
  local file="$1" base="$2"
  local custom
  custom=$(extract_yaml_field "$file" "cursor_rule_name")
  if [ -n "$custom" ]; then
    case "$custom" in
      *.mdc) printf '%s' "$custom" ;;
      *)     printf '%s.mdc' "$custom" ;;
    esac
  else
    printf '%s.mdc' "$base"
  fi
}

# $1 = source md path, $2 = output .mdc path (no dir), $3 = Cursor rule description (plain text)
write_mdc() {
  local src="$1"
  local dest_name="$2"
  local desc="$3"
  local dest="$PROJECT_ROOT/.cursor/rules/$dest_name"
  local esc
  esc=$(escape_yaml_double "$desc")
  mkdir -p "$PROJECT_ROOT/.cursor/rules"
  {
    printf '%s\n' "---"
    printf '%s\n' "description: \"$esc\""
    printf '%s\n' "alwaysApply: false"
    printf '%s\n' "---"
    printf '\n'
    printf '%s\n' "$AGENTIC_MARKER"
    printf '\n'
    strip_frontmatter_body "$src"
  } > "$dest"
}

# ensure_symlink <label> <target_path> <link_value>
# Returns 0 if linked/already linked/overwritten, 1 if skipped
ensure_symlink() {
  local label="$1" target="$2" link="$3"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$link" ]; then
    info "$label (already linked)"
    return 0
  fi
  if [ -e "$target" ] || [ -L "$target" ]; then
    if should_overwrite "$label"; then
      rm -rf "$target"
      ln -s "$link" "$target"
      success "$label (overwritten)"
      return 0
    fi
    return 1
  fi
  ln -s "$link" "$target"
  success "$label"
  return 0
}

# Write kit-managed file: skip if exists without marker; prompt if kit-managed; create or overwrite.
# Usage: write_if_kit_managed <human_label> <dest_path> <write_fn> [args to write_fn...]
# write_fn receives dest as last argument (caller passes dest twice: once as $2, once as arg to fn)
write_if_kit_managed() {
  local label="$1" dest="$2" writer="$3"
  shift 3
  if [ -f "$dest" ]; then
    if ! grep -qF "$AGENTIC_MARKER" "$dest" 2>/dev/null; then
      case "$label" in
        AGENTS.md) skip "$label (not kit-managed — merge manually)" ;;
        *)         skip "$label (not kit-managed)" ;;
      esac
      return 1
    fi
    if should_overwrite "$label"; then
      "$writer" "$@"
      success "$label (overwritten)"
      return 0
    fi
    return 1
  fi
  "$writer" "$@"
  success "$label"
  return 0
}

write_agents_md_body() {
  local dest="$1"
  {
    printf '%s\n' "$AGENTIC_MARKER"
    printf '\n'
    cat "$SCRIPT_DIR/PIPELINE.md.template"
  } > "$dest"
}

# $1 = dest path; uses PIPELINE_MDC_BODY (set by caller)
write_pipeline_mdc_body() {
  local dest="$1"
  {
    printf '%s\n' "---"
    printf '%s\n' "description: \"Agentic kit — pipeline overview, handoff protocol, invocation map\""
    printf '%s\n' "alwaysApply: true"
    printf '%s\n' "---"
    printf '\n'
    printf '%s\n' "$AGENTIC_MARKER"
    printf '\n'
    printf '%s\n' "$PIPELINE_MDC_BODY"
  } > "$dest"
}

install_or_update_mdc_rule() {
  local rel_label="$1" src="$2" out_name="$3" desc="$4"
  local dest="$PROJECT_ROOT/.cursor/rules/$out_name"

  if [ -f "$dest" ]; then
    if ! grep -qF "$AGENTIC_MARKER" "$dest" 2>/dev/null; then
      skip "$rel_label (not kit-managed — delete manually to replace)"
      return 1
    fi
    if should_overwrite "$rel_label"; then
      write_mdc "$src" "$out_name" "$desc"
      success "$rel_label (overwritten)"
    fi
  else
    write_mdc "$src" "$out_name" "$desc"
    success "$rel_label"
  fi
}

generate_mdc_rules_from_sources() {
  local agent base out desc skill_dir skill_name skill_file
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    base=$(basename "$agent" .md)
    out=$(cursor_rule_out_name "$agent" "$base")
    desc=$(extract_yaml_field "$agent" "description")
    [ -n "$desc" ] || desc="Agent: $base"
    install_or_update_mdc_rule ".cursor/rules/$out" "$agent" "$out" "$desc"
  done

  local skill_dir skill_name skill_file
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"
    [ -f "$skill_file" ] || continue
    out=$(cursor_rule_out_name "$skill_file" "$skill_name")
    desc=$(extract_yaml_field "$skill_file" "description")
    [ -n "$desc" ] || desc="Skill: $skill_name"
    install_or_update_mdc_rule ".cursor/rules/$out" "$skill_file" "$out" "$desc"
  done
}

# Optional $1 overrides section header (cursor-only uses the longer label).
link_claude_skills() {
  header "${1:-Claude Code — Skills}"
  mkdir -p "$PROJECT_ROOT/.claude/skills"

  local skill_dir name target link
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    target="$PROJECT_ROOT/.claude/skills/$name"
    link="../../$SUBMODULE_DIR/skills/$name"
    ensure_symlink ".claude/skills/$name" "$target" "$link" || true
  done
}

setup_cursor_rules_from_sources() {
  header "Cursor rules (.cursor/rules/)"

  generate_mdc_rules_from_sources

  local pipe="$PROJECT_ROOT/.cursor/rules/pipeline.mdc"
  PIPELINE_MDC_BODY=$(grep -v '^@PROJECT.md$' "$SCRIPT_DIR/PIPELINE.md.template")
  write_if_kit_managed ".cursor/rules/pipeline.mdc" "$pipe" write_pipeline_mdc_body "$pipe"
}

setup_agents_md() {
  header "AGENTS.md (Cursor / cross-tool)"
  local dest="$PROJECT_ROOT/AGENTS.md"
  write_if_kit_managed "AGENTS.md" "$dest" write_agents_md_body "$dest"
}

setup_tools_symlink() {
  header "Tools"
  local TOOLS_TARGET="$PROJECT_ROOT/tools"
  local link="$SUBMODULE_DIR/tools"
  ensure_symlink "tools/" "$TOOLS_TARGET" "$link" || true
}

setup_claude() {
  header "Claude Code — Agents"
  mkdir -p "$PROJECT_ROOT/.claude/agents"

  local agent name target link
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    name=$(basename "$agent")
    target="$PROJECT_ROOT/.claude/agents/$name"
    link="../../$SUBMODULE_DIR/agents/$name"
    ensure_symlink ".claude/agents/$name" "$target" "$link" || true
  done

  link_claude_skills

  header "Claude Code — CLAUDE.md"
  if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    if should_overwrite "CLAUDE.md"; then
      cp "$SCRIPT_DIR/PIPELINE.md.template" "$PROJECT_ROOT/CLAUDE.md"
      success "CLAUDE.md (overwritten from template)"
    fi
  else
    cp "$SCRIPT_DIR/PIPELINE.md.template" "$PROJECT_ROOT/CLAUDE.md"
    success "CLAUDE.md"
  fi
}

setup_cursor() {
  # Cursor-only: symlink skills so paths like .claude/skills/vadavik/new-feature.sh work.
  # "both" already linked skills in setup_claude.
  if [ "$IDE_CHOICE" = "cursor" ]; then
    link_claude_skills "Claude Code — Skills (for bundled scripts)"
  fi
  setup_cursor_rules_from_sources
  setup_agents_md
}

# ---------------------------------------------------------------------------
# IDE choice
# ---------------------------------------------------------------------------
printf "\n${BOLD}${CYAN}  agentic-kit${RESET}\n"
info "project root: $PROJECT_ROOT"
info "kit location: $SUBMODULE_DIR/"

if [ -z "$IDE_CHOICE" ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    printf "\n  Target IDE? [${BOLD}c${RESET}]laude  c${BOLD}[u]${RESET}rsor  [${BOLD}b${RESET}]oth  (default: claude) "
    read -r -n1 ide_key
    printf '\n'
    case "$ide_key" in
      u|U) IDE_CHOICE="cursor" ;;
      b|B) IDE_CHOICE="both" ;;
      *)   IDE_CHOICE="claude" ;;
    esac
  else
    IDE_CHOICE="claude"
  fi
fi

info "IDE mode: $IDE_CHOICE"

# ---------------------------------------------------------------------------
# Run setups
# ---------------------------------------------------------------------------
case "$IDE_CHOICE" in
  claude)
    setup_claude
    ;;
  cursor)
    setup_cursor
    ;;
  both)
    setup_claude
    setup_cursor
    ;;
  *)
    err "Invalid IDE mode '$IDE_CHOICE' (use claude, cursor, or both)"
    exit 1
    ;;
esac

setup_tools_symlink

# ---------------------------------------------------------------------------
# PROJECT.md (shared)
# ---------------------------------------------------------------------------
header "PROJECT.md"

fresh_project_md_from_template=false

if [ -f "$PROJECT_ROOT/PROJECT.md" ]; then
  if should_overwrite "PROJECT.md"; then
    cp "$SCRIPT_DIR/PROJECT.md.template" "$PROJECT_ROOT/PROJECT.md"
    success "PROJECT.md (overwritten from template)"
    fresh_project_md_from_template=true
  fi
else
  cp "$SCRIPT_DIR/PROJECT.md.template" "$PROJECT_ROOT/PROJECT.md"
  success "PROJECT.md"
  fresh_project_md_from_template=true
fi

if [ "$fresh_project_md_from_template" = true ]; then
  # Optional AI fill: Claude Code CLI vs Cursor Agent CLI — see https://cursor.com/docs/cli/installation
  project_md_fill_prompt="Inspect this project's files (e.g. package.json, pyproject.toml, Makefile, Cargo.toml, go.mod — whatever exists) to infer the test command, build command, and any version files. Then fill in all the placeholder values in PROJECT.md and write the completed file. Only ask me if you genuinely cannot determine a value."

  # On Windows, the Cursor Agent CLI is installed on the Windows PATH but Git Bash / MSYS2 inherit
  # their own PATH subset.  Fall back to PowerShell to resolve the real exe path.
  find_agent_bin() {
    if command -v agent &>/dev/null; then
      command -v agent
      return 0
    fi
    if command -v powershell.exe &>/dev/null; then
      local p
      p=$(powershell.exe -NoProfile -Command \
        "Get-Command agent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source" \
        2>/dev/null | tr -d '\r\n')
      if [ -n "$p" ]; then
        printf '%s' "$p"
        return 0
      fi
    fi
    return 1
  }

  AGENT_BIN=""
  fill_cli=""
  fill_label=""
  case "$IDE_CHOICE" in
    claude)
      if command -v claude &>/dev/null; then
        fill_cli="claude"
        fill_label="Claude"
      fi
      ;;
    cursor)
      # Use the Cursor Agent CLI (`agent` from https://cursor.com/install), not the desktop `cursor`
      # launcher — that binary is Electron/Chromium and treats unknown flags like -p as Chromium args.
      AGENT_BIN=$(find_agent_bin 2>/dev/null) || AGENT_BIN=""
      if [ -n "$AGENT_BIN" ]; then
        fill_cli="agent"
        fill_label="Cursor Agent"
      fi
      ;;
    both)
      if command -v claude &>/dev/null; then
        fill_cli="claude"
        fill_label="Claude"
      else
        AGENT_BIN=$(find_agent_bin 2>/dev/null) || AGENT_BIN=""
        if [ -n "$AGENT_BIN" ]; then
          fill_cli="agent"
          fill_label="Cursor Agent"
        fi
      fi
      ;;
  esac

  # Prompt on stdin, or /dev/tty when stdin is piped but a real terminal exists (IDEs / CI sometimes leave stdin non-TTY).
  project_md_can_prompt=false
  if [ -t 0 ]; then
    project_md_can_prompt=true
  elif { : >/dev/tty; } 2>/dev/null; then
    # Require a working /dev/tty for read+write; -r alone can pass on Git Bash while redirects fail.
    project_md_can_prompt=true
  fi

  if [ -n "$fill_cli" ] && [ "$project_md_can_prompt" = true ]; then
    printf '\n'
    if [ -t 0 ]; then
      printf "  Fill in ${BOLD}PROJECT.md${RESET} automatically using ${fill_label}? [${BOLD}Y${RESET}/n] "
      read -r yn
    else
      printf "  Fill in ${BOLD}PROJECT.md${RESET} automatically using ${fill_label}? [${BOLD}Y${RESET}/n] " > /dev/tty
      read -r yn < /dev/tty
    fi
    yn="${yn:-Y}"
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      info "Running ${fill_label}..."
      case "$fill_cli" in
        claude)
          ( cd "$PROJECT_ROOT" && claude -p --allowedTools 'Edit,Write,Read,Glob,Grep,Bash' "$project_md_fill_prompt" )
          ;;
        agent)
          ( cd "$PROJECT_ROOT" && "$AGENT_BIN" -p --force "$project_md_fill_prompt" )
          ;;
      esac
      success "PROJECT.md filled in"
      info "Run ${SUBMODULE_DIR}/tools/validate-config.sh to verify."
    else
      info "Edit PROJECT.md manually, then run: ${SUBMODULE_DIR}/tools/validate-config.sh"
    fi
  else
    if [ -n "$fill_cli" ] && [ "$project_md_can_prompt" = false ]; then
      info "PROJECT.md auto-fill skipped (no TTY for Y/n — stdin is not a terminal and /dev/tty is unavailable). Edit PROJECT.md manually or run your IDE CLI from the project root with the same task."
    fi
    if [ -z "$fill_cli" ]; then
      case "$IDE_CHOICE" in
        claude)
          info "Claude CLI (\`claude\`) not on PATH — install Claude Code or edit PROJECT.md manually."
          ;;
        cursor)
          info "Cursor Agent CLI (\`agent\`) not on PATH — https://cursor.com/docs/cli/installation (the desktop \`cursor\` command is the editor, not this CLI)."
          ;;
        both)
          info "Neither \`claude\` nor \`agent\` (Cursor Agent CLI) on PATH — install one or edit PROJECT.md manually."
          ;;
      esac
    fi
    info "Edit PROJECT.md → Project-Specific Configuration, then run:"
    info "${SUBMODULE_DIR}/tools/validate-config.sh"
  fi
fi

# ---------------------------------------------------------------------------
# .gitignore
# ---------------------------------------------------------------------------
header ".gitignore"
GITIGNORE="$PROJECT_ROOT/.gitignore"

# Add more entries here alongside teardown.sh's removal loop.
for entry in ".artefacts/"; do
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF "$entry" "$GITIGNORE"; then
    printf '%s\n' "$entry" >> "$GITIGNORE"
    success ".gitignore ← $entry"
  else
    info "$entry already in .gitignore"
  fi
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  Done.${RESET}\n"
case "$IDE_CHOICE" in
  claude)  info "Claude Code: start a feature with /vadavik" ;;
  cursor)  info "Cursor: .mdc rules generated — re-run init after submodule update" ;;
  both)    info "Claude Code: /vadavik  |  Cursor: rules in .cursor/rules/" ;;
esac
printf '\n'
