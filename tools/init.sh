#!/usr/bin/env bash
# Run from the target project root after adding the submodule.
# Usage: agentic-kit/tools/init.sh [--force | --overwrite-all | --skip | --skip-all | --non-interactive] [--ide=claude|cursor|github|all]
# Env: IDE_CHOICE=claude|cursor|github|all (same as --ide, for non-interactive)
#
# What this script does (minimally invasive by design):
#
#   1.  Creates `.agentic-kit-artefacts/` and copies the canonical pipeline doc
#       and project config there:
#         .agentic-kit-artefacts/PIPELINE.md   (kit-managed; refreshed on update)
#         .agentic-kit-artefacts/PROJECT.md    (you edit; kept on update)
#
#   2.  Installs the per-IDE machinery (skills + agents) into `.claude/`,
#       `.cursor/`, and/or `.github/`. SHA-256 of every installed file is
#       recorded in `.agentic-kit-artefacts/.agentic-kit.files` so teardown.sh refuses to delete
#       paths you have edited locally.
#
#   3.  Adds a small marker block to (or creates) the IDE entry-point file:
#         CLAUDE.md, AGENTS.md, .github/copilot-instructions.md
#       Block delimiters: <!-- agentic-kit:start --> ... <!-- agentic-kit:end -->
#       The block points at .agentic-kit-artefacts/PIPELINE.md. Existing user
#       content above/below the markers is preserved verbatim. We never rename
#       or overwrite PIPELINE.md as CLAUDE.md/AGENTS.md again.
#
#   4.  Adds a managed block to .gitignore for ephemeral state under
#         .agentic-kit-artefacts/{memory,features,archive,…} plus
#         .agentic-kit-artefacts/.agentic-kit.cfg and .agentic-kit-artefacts/.agentic-kit.files
#       PIPELINE.md and PROJECT.md inside .agentic-kit-artefacts/ are NOT
#       ignored — your team should commit them.
#
# Flags:
#   --force, --overwrite-all   Overwrite all existing kit-managed paths without prompting
#   --skip, --skip-all         Skip every existing path without prompting
#   --non-interactive, -n      Agent / CI mode: no prompts, skip existing files, emit
#                              [AGENT ACTION REQUIRED] instruction to fill PROJECT.md
#                              (aliases: --yes, -y)
#   --ide=X                    Target IDE: claude (default), cursor, github, or all
#
# Interactive conflict prompt: [s]kip this  [o]verwrite this  overwrite [a]ll  skip [r]est
#
# Agent invocation examples:
#   agentic-kit/tools/init.sh --non-interactive                      # claude (default)
#   agentic-kit/tools/init.sh --non-interactive --ide=cursor
#   agentic-kit/tools/init.sh --non-interactive --ide=both

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

kit_migrate_legacy_root_state

# Canonical project-local locations (after migration from .artefacts/)
PIPELINE_REL="$ARTEFACTS_DIR_NAME/PIPELINE.md"
PROJECT_REL="$ARTEFACTS_DIR_NAME/PROJECT.md"
PIPELINE_TARGET="$PROJECT_ROOT/$PIPELINE_REL"
PROJECT_TARGET="$PROJECT_ROOT/$PROJECT_REL"
PIPELINE_TEMPLATE="$SCRIPT_DIR/templates/PIPELINE.md.template"
PROJECT_TEMPLATE="$SCRIPT_DIR/templates/PROJECT.md.template"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  cat <<'EOF'

  agentic-kit / init.sh

  Set up the AI development kit in the current project.
  Run from the project root (the directory that contains agentic-kit/).

  USAGE
    agentic-kit/tools/init.sh [OPTIONS]

  WHAT GETS WRITTEN
    .agentic-kit-artefacts/PIPELINE.md       canonical pipeline (kit-managed)
    .agentic-kit-artefacts/PROJECT.md        project-specific config (you edit)
    .agentic-kit-artefacts/{memory,features,archive,…}
                                             runtime state (gitignored)
    .agentic-kit-artefacts/.agentic-kit.cfg   saved IDE + pipeline SHA (gitignored)
    .agentic-kit-artefacts/.agentic-kit.files kit install manifest (gitignored)

    .claude/  .cursor/  .github/             one folder per IDE you target
    CLAUDE.md / AGENTS.md / copilot-instructions.md
                                             tiny include block pointing at
                                             .agentic-kit-artefacts/PIPELINE.md
                                             (existing user content preserved)
    .gitignore                               managed block for ephemeral state

  OPTIONS
    --ide=<target>          Which IDE to configure (default: claude)
                              claude   — Claude Code (.claude/ copies, CLAUDE.md include block)
                              cursor   — Cursor (.cursor/skills/ copies, .cursor/agents/*.md subagents,
                                         AGENTS.md include block)
                              github   — GitHub Copilot (.github/agents/*.agent.md,
                                         .github/instructions/*.instructions.md,
                                         .github/copilot-instructions.md include block)
                              all      — all three  (alias: both)
                            Env var: IDE_CHOICE=claude|cursor|github|all

    --non-interactive, -n   Agent / CI mode: no prompts, accept all defaults,
                            skip existing files, and print [AGENT ACTION REQUIRED]
                            instead of spawning a nested AI process.
                            Aliases: --yes, -y

    --skip, --skip-all      Skip every existing path without prompting
                            (automatic when stdin is not a TTY)

    --force, --overwrite-all
                            Overwrite all existing kit-managed files without prompting

    --tune                  After install, probe the project (stack, frameworks,
                            test/build commands, conventions) and write
                            .agentic-kit-artefacts/PROJECT_PROFILE.md so agents
                            can self-tune. Calls
                            `agentic-kit/tools/probe-project.sh --force`.
    --no-tune               Skip the probe step (default).

    --help, -h              Show this help and exit

  INTERACTIVE CONFLICT PROMPT
    When a managed path already exists:
      s  skip this file
      o  overwrite this file
      a  overwrite all remaining files
      r  skip rest (this file and every later conflict)

  AGENT INVOCATION
    agentic-kit/tools/init.sh --non-interactive --ide=claude
    agentic-kit/tools/init.sh --non-interactive --ide=cursor
    agentic-kit/tools/init.sh --non-interactive --ide=github
    agentic-kit/tools/init.sh --non-interactive --ide=all

    After the script exits, read the [AGENT ACTION REQUIRED] block in the output
    and fill in .agentic-kit-artefacts/PROJECT.md yourself (inspect package.json,
    pyproject.toml, Cargo.toml, go.mod, Makefile, etc.), then run:
      agentic-kit/tools/validate-config.sh

  EXAMPLES
    agentic-kit/tools/init.sh                          # interactive
    agentic-kit/tools/init.sh --ide=github             # interactive, GitHub Copilot mode
    agentic-kit/tools/init.sh --non-interactive --ide=github
    IDE_CHOICE=all agentic-kit/tools/init.sh --skip

EOF
}

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
NON_INTERACTIVE=false
IDE_CHOICE="${IDE_CHOICE:-}"
TUNE=false

for arg in "$@"; do
  case "$arg" in
    --help|-h)                       show_help; exit 0 ;;
    --force|--overwrite-all)         MODE="force" ;;
    --skip|--skip-all)               MODE="skip" ;;
    --non-interactive|-n|--yes|-y)   NON_INTERACTIVE=true ;;
    --ide=*)                         IDE_CHOICE="${arg#--ide=}" ;;
    --tune)                          TUNE=true ;;
    --no-tune)                       TUNE=false ;;
  esac
done

# No args + no TTY → agent discovered the script; show help so it knows what to pass next.
if [ $# -eq 0 ] && [ ! -t 0 ] && [ ! -t 1 ]; then
  show_help
  exit 0
fi

# --non-interactive implies skip-existing (safe default: don't overwrite without being asked)
if $NON_INTERACTIVE && [ -z "$MODE" ]; then MODE="skip"; fi

if [ -n "$IDE_CHOICE" ] && [[ ! "$IDE_CHOICE" =~ ^(claude|cursor|github|both|all)$ ]]; then
  err "Invalid --ide value '$IDE_CHOICE' (use claude, cursor, github, all, or both)"
  exit 1
fi
# Normalise alias
[ "$IDE_CHOICE" = "both" ] && IDE_CHOICE="all"

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

# Copy kit file into project; record SHA-256 in .agentic-kit-artefacts/.agentic-kit.files for teardown.
# Usage: install_kit_copy_file <label> <rel_path> <src_file_abs>
install_kit_copy_file() {
  local label="$1" rel_path="$2" src_file="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded

  want=$(kit_sha256_file "$src_file") || return 1
  mkdir -p "$(dirname "$target")"
  recorded=$(manifest_get_hash "$rel_path" || true)

  if [ -L "$target" ] || [ ! -e "$target" ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (exists — use --force to replace)"
        return 1
      fi
      rm -rf "$target"
    fi
    cp "$src_file" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_file "$target")"
    success "$label"
    return 0
  fi

  if [ ! -f "$target" ]; then
    if ! should_overwrite "$label"; then skip "$label (not a regular file)"; return 1; fi
    rm -rf "$target"
    cp "$src_file" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_file "$target")"
    success "$label"
    return 0
  fi

  have=$(kit_sha256_file "$target")
  if [ "$have" = "$want" ]; then
    manifest_set_hash "$rel_path" "$want"
    info "$label (matches kit)"
    return 0
  fi
  if [ -n "$recorded" ] && [ "$have" = "$recorded" ]; then
    if ! should_overwrite "$label"; then
      skip "$label (kit updated in submodule — use --force to refresh)"
      return 1
    fi
    rm -f "$target"
    cp "$src_file" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_file "$target")"
    success "$label (refreshed from kit)"
    return 0
  fi
  if [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
    if ! should_overwrite "$label"; then
      skip "$label (modified locally — use --force to replace)"
      return 1
    fi
    rm -f "$target"
    cp "$src_file" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_file "$target")"
    success "$label (overwritten)"
    return 0
  fi
  if ! should_overwrite "$label"; then
    skip "$label (exists — use --force)"
    return 1
  fi
  rm -f "$target"
  cp "$src_file" "$target"
  manifest_set_hash "$rel_path" "$(kit_sha256_file "$target")"
  success "$label (overwritten)"
  return 0
}

# Copy skill directory tree; record aggregate SHA-256 of all files.
# Usage: install_kit_copy_tree <label> <rel_path> <src_dir_abs>
install_kit_copy_tree() {
  local label="$1" rel_path="$2" src_dir="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded

  want=$(kit_sha256_tree "$src_dir") || return 1
  mkdir -p "$(dirname "$target")"
  recorded=$(manifest_get_hash "$rel_path" || true)

  if [ -L "$target" ] || [ ! -e "$target" ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (exists — use --force to replace)"
        return 1
      fi
      rm -rf "$target"
    fi
    cp -R "$src_dir" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_tree "$target")"
    success "$label"
    return 0
  fi

  if [ ! -d "$target" ] || [ -L "$target" ]; then
    if ! should_overwrite "$label"; then skip "$label (not a directory)"; return 1; fi
    rm -rf "$target"
    cp -R "$src_dir" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_tree "$target")"
    success "$label"
    return 0
  fi

  have=$(kit_sha256_tree "$target")
  if [ "$have" = "$want" ]; then
    manifest_set_hash "$rel_path" "$want"
    info "$label (matches kit)"
    return 0
  fi
  if [ -n "$recorded" ] && [ "$have" = "$recorded" ]; then
    if ! should_overwrite "$label"; then
      skip "$label (kit skill updated — use --force)"
      return 1
    fi
    rm -rf "$target"
    cp -R "$src_dir" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_tree "$target")"
    success "$label (refreshed from kit)"
    return 0
  fi
  if [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
    if ! should_overwrite "$label"; then
      skip "$label (modified locally — use --force)"
      return 1
    fi
    rm -rf "$target"
    cp -R "$src_dir" "$target"
    manifest_set_hash "$rel_path" "$(kit_sha256_tree "$target")"
    success "$label (overwritten)"
    return 0
  fi
  if ! should_overwrite "$label"; then
    skip "$label (exists — use --force)"
    return 1
  fi
  rm -rf "$target"
  cp -R "$src_dir" "$target"
  manifest_set_hash "$rel_path" "$(kit_sha256_tree "$target")"
  success "$label (overwritten)"
  return 0
}

# ---------------------------------------------------------------------------
# YAML helpers + Cursor subagents (https://cursor.com/docs/context/subagents)
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

# Subagent id / filename stem: optional cursor_subagent_name, else cursor_rule_name (legacy), else agent basename
cursor_subagent_stem() {
  local file="$1" base="$2"
  local custom
  custom=$(extract_yaml_field "$file" "cursor_subagent_name")
  if [ -z "$custom" ]; then
    custom=$(extract_yaml_field "$file" "cursor_rule_name")
  fi
  if [ -n "$custom" ]; then
    case "$custom" in
      *.md)  printf '%s' "${custom%.md}" ;;
      *.mdc) printf '%s' "${custom%.mdc}" ;;
      *)     printf '%s' "$custom" ;;
    esac
  else
    printf '%s' "$base"
  fi
}

# Single path segment, Cursor-style id (lowercase letters, digits, hyphens). Else unsafe for dest path.
cursor_subagent_stem_safe() {
  local file="$1" base="$2"
  local stem
  stem=$(cursor_subagent_stem "$file" "$base")
  if [[ "$stem" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    printf '%s' "$stem"
    return 0
  fi
  warn "Invalid cursor_subagent_name / cursor_rule_name '${stem}' in $(basename "$file") — using '${base}'"
  printf '%s' "$base"
}

yaml_truthy_is_background() {
  local v="$1"
  case "$v" in
    true|True|TRUE|yes|Yes|1) printf 'true' ;;
    *)                        printf 'false' ;;
  esac
}

write_cursor_subagent() {
  local src="$1" dest="$2"
  local stem name desc esc_name esc_desc bg is_bg
  stem=$(cursor_subagent_stem_safe "$src" "$(basename "$src" .md)")
  name="$stem"
  desc=$(extract_yaml_field "$src" "description")
  [ -n "$desc" ] || desc="Agent: $name"
  esc_name=$(escape_yaml_double "$name")
  esc_desc=$(escape_yaml_double "$desc")
  bg=$(extract_yaml_field "$src" "background")
  is_bg=$(yaml_truthy_is_background "$bg")
  mkdir -p "$(dirname "$dest")"
  {
    printf '%s\n' "---"
    printf '%s\n' "name: \"$esc_name\""
    printf '%s\n' "description: \"$esc_desc\""
    printf '%s\n' "model: inherit"
    printf '%s\n' "readonly: false"
    printf '%s\n' "is_background: $is_bg"
    printf '%s\n' "---"
    printf '\n'
    printf '%s\n' "$AGENTIC_MARKER"
    printf '\n'
    strip_frontmatter_body "$src"
  } > "$dest"
}

install_or_update_cursor_subagent_file() {
  local src="$1"
  local stem dest rel_label
  stem=$(cursor_subagent_stem_safe "$src" "$(basename "$src" .md)")
  dest="$PROJECT_ROOT/.cursor/agents/${stem}.md"
  rel_label=".cursor/agents/${stem}.md"

  if [ -f "$dest" ]; then
    if ! grep -qF "$AGENTIC_MARKER" "$dest" 2>/dev/null; then
      skip "$rel_label (not kit-managed — delete manually to replace)"
      return 1
    fi
    if should_overwrite "$rel_label"; then
      write_cursor_subagent "$src" "$dest"
      manifest_set_hash "$rel_label" "$(kit_sha256_file "$dest")"
      success "$rel_label (overwritten)"
    else
      manifest_set_hash "$rel_label" "$(kit_sha256_file "$dest")"
      info "$rel_label (unchanged — manifest synced)"
    fi
  else
    write_cursor_subagent "$src" "$dest"
    manifest_set_hash "$rel_label" "$(kit_sha256_file "$dest")"
    success "$rel_label"
  fi
}

generate_cursor_subagents_from_sources() {
  local agent
  mkdir -p "$PROJECT_ROOT/.cursor/agents"
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    install_or_update_cursor_subagent_file "$agent"
  done
}

# ---------------------------------------------------------------------------
# Managed include block — entry-point file (CLAUDE.md / AGENTS.md / copilot-instructions.md)
#
# Behaviour matrix:
#   file missing                → write a small stub with the include block
#   file present, block missing → append the block (existing content kept)
#   file present, block present → leave as-is unless --force, then refresh block
# ---------------------------------------------------------------------------
install_pipeline_include() {
  local label="$1" dest_rel="$2" ide_label="$3"
  local dest="$PROJECT_ROOT/$dest_rel"
  local block_sha

  if [ -f "$dest" ]; then
    if agentic_block_present "$dest"; then
      if should_overwrite "$label"; then
        agentic_block_strip "$dest" >/dev/null 2>&1 || true
        agentic_block_append "$dest" "$PIPELINE_REL" "$ide_label"
        block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL" "$ide_label")")
        manifest_set_hash "$dest_rel" "block:$block_sha"
        success "$label (block refreshed)"
      else
        block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL" "$ide_label")")
        manifest_set_hash "$dest_rel" "block:$block_sha"
        info "$label (block already present — manifest synced)"
      fi
    else
      agentic_block_append "$dest" "$PIPELINE_REL" "$ide_label"
      block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL" "$ide_label")")
      manifest_set_hash "$dest_rel" "block:$block_sha"
      success "$label (block appended; existing content preserved)"
    fi
    return 0
  fi

  agentic_block_write_stub "$dest" "$PIPELINE_REL" "$ide_label"
  block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL" "$ide_label")")
  manifest_set_hash "$dest_rel" "stub:$(kit_sha256_file "$dest")"
  success "$label (created with include block)"
}

# ---------------------------------------------------------------------------
# Cursor Agent Skills: one folder per skill with SKILL.md
# ---------------------------------------------------------------------------
link_cursor_skills() {
  header "Cursor — Skills (.cursor/skills/)"

  local skill_dir name skill_file src_dir rel
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"
    [ -f "$skill_file" ] || continue
    src_dir="${skill_dir%/}"
    rel=".cursor/skills/$name"
    install_kit_copy_tree ".cursor/skills/$name" "$rel" "$src_dir" || true
  done
}

# Optional $1 overrides section header (cursor-only uses the longer label).
link_claude_skills() {
  header "${1:-Claude Code — Skills}"

  local skill_dir name skill_file src_dir rel
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"
    [ -f "$skill_file" ] || continue
    src_dir="${skill_dir%/}"
    rel=".claude/skills/$name"
    install_kit_copy_tree ".claude/skills/$name" "$rel" "$src_dir" || true
  done
}

setup_cursor_subagents() {
  header "Cursor — Subagents (.cursor/agents/)"
  generate_cursor_subagents_from_sources
}

# ---------------------------------------------------------------------------
# Per-IDE setups (each calls install_pipeline_include for its entry-point file)
# ---------------------------------------------------------------------------
setup_claude() {
  header "Claude Code — Agents"

  local agent name rel
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    name=$(basename "$agent")
    rel=".claude/agents/$name"
    install_kit_copy_file ".claude/agents/$name" "$rel" "$agent" || true
  done

  link_claude_skills

  header "Claude Code — CLAUDE.md (managed include block)"
  install_pipeline_include "CLAUDE.md" "CLAUDE.md" "Claude Code"
}

setup_cursor() {
  # Cursor-only: copy skills so paths like .claude/skills/vadavik/new-feature.sh work.
  # "all" already linked skills via setup_claude.
  if [ "$IDE_CHOICE" = "cursor" ]; then
    link_claude_skills "Claude Code — Skills (for bundled scripts)"
  fi
  link_cursor_skills
  setup_cursor_subagents

  header "AGENTS.md (managed include block)"
  install_pipeline_include "AGENTS.md" "AGENTS.md" "Cursor"
}

# ---------------------------------------------------------------------------
# GitHub Copilot helpers
# Write .github/agents/<name>.agent.md from a kit agent source file.
# Strips Claude-specific fields; keeps name + description; adds tools list.
write_github_agent() {
  local src="$1" dest="$2"
  local name desc esc_desc
  name=$(extract_yaml_field "$src" "name")
  desc=$(extract_yaml_field "$src" "description")
  esc_desc=$(escape_yaml_double "$desc")
  mkdir -p "$(dirname "$dest")"
  {
    echo "---"
    echo "name: \"$name\""
    echo "description: \"$esc_desc\""
    # Standard Copilot agent tools — agents can read/edit/run/search without extra config.
    echo "tools: ['changes','codebase','editFiles','fetch','findTestFiles','problems','runCommands','runTests','search','terminalLastCommand','usages']"
    echo "---"
    echo ""
    echo "$AGENTIC_MARKER"
    echo ""
    strip_frontmatter_body "$src"
  } > "$dest"
}

# Write .github/instructions/<name>.instructions.md from a kit skill source file.
write_github_instructions() {
  local src="$1" dest="$2"
  local name desc esc_desc
  name=$(extract_yaml_field "$src" "name")
  desc=$(extract_yaml_field "$src" "description")
  esc_desc=$(escape_yaml_double "$desc")
  mkdir -p "$(dirname "$dest")"
  {
    echo "---"
    echo "name: \"$name\""
    echo "description: \"$esc_desc\""
    echo "applyTo: '**'"
    echo "---"
    echo ""
    echo "$AGENTIC_MARKER"
    echo ""
    strip_frontmatter_body "$src"
  } > "$dest"
}

setup_github() {
  # GitHub Copilot-only: copy skills for bundled shell scripts (same as Cursor-only).
  if [ "$IDE_CHOICE" = "github" ]; then
    link_claude_skills "Claude Code — Skills (for bundled scripts)"
  fi

  # .github/agents/*.agent.md
  header "GitHub Copilot — Agents (.github/agents/)"
  mkdir -p "$PROJECT_ROOT/.github/agents"
  local agent base out dest
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    base=$(basename "$agent" .md)
    out="${base}.agent.md"
    dest="$PROJECT_ROOT/.github/agents/$out"
    if [ -f "$dest" ]; then
      if ! grep -qF "$AGENTIC_MARKER" "$dest" 2>/dev/null; then
        skip ".github/agents/$out (not kit-managed — delete manually to replace)"
      elif should_overwrite ".github/agents/$out"; then
        write_github_agent "$agent" "$dest"
        manifest_set_hash ".github/agents/$out" "$(kit_sha256_file "$dest")"
        success ".github/agents/$out (overwritten)"
      else
        manifest_set_hash ".github/agents/$out" "$(kit_sha256_file "$dest")"
        info ".github/agents/$out (unchanged — manifest synced)"
      fi
    else
      write_github_agent "$agent" "$dest"
      manifest_set_hash ".github/agents/$out" "$(kit_sha256_file "$dest")"
      success ".github/agents/$out"
    fi
  done

  # .github/instructions/*.instructions.md
  header "GitHub Copilot — Instructions (.github/instructions/)"
  mkdir -p "$PROJECT_ROOT/.github/instructions"
  local skill_dir skill_name skill_file
  for skill_dir in "$SCRIPT_DIR/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"
    [ -f "$skill_file" ] || continue
    out="${skill_name}.instructions.md"
    dest="$PROJECT_ROOT/.github/instructions/$out"
    if [ -f "$dest" ]; then
      if ! grep -qF "$AGENTIC_MARKER" "$dest" 2>/dev/null; then
        skip ".github/instructions/$out (not kit-managed — delete manually to replace)"
      elif should_overwrite ".github/instructions/$out"; then
        write_github_instructions "$skill_file" "$dest"
        manifest_set_hash ".github/instructions/$out" "$(kit_sha256_file "$dest")"
        success ".github/instructions/$out (overwritten)"
      else
        manifest_set_hash ".github/instructions/$out" "$(kit_sha256_file "$dest")"
        info ".github/instructions/$out (unchanged — manifest synced)"
      fi
    else
      write_github_instructions "$skill_file" "$dest"
      manifest_set_hash ".github/instructions/$out" "$(kit_sha256_file "$dest")"
      success ".github/instructions/$out"
    fi
  done

  header "GitHub Copilot — copilot-instructions.md (managed include block)"
  mkdir -p "$PROJECT_ROOT/.github"
  install_pipeline_include ".github/copilot-instructions.md" ".github/copilot-instructions.md" "GitHub Copilot"
}

# ---------------------------------------------------------------------------
# .agentic-kit-artefacts/ (canonical home for PIPELINE.md and PROJECT.md)
# ---------------------------------------------------------------------------
setup_artefacts_dir() {
  header "$ARTEFACTS_DIR_NAME/ (pipeline + project config)"
  mkdir -p "$ARTEFACTS_DIR"

  # PIPELINE.md — kit-managed copy of the template, refreshed on update.
  install_kit_copy_file "$PIPELINE_REL" "$PIPELINE_REL" "$PIPELINE_TEMPLATE" || true

  # PROJECT.md — copied once from the template; user edits and we keep their copy.
  # We track it in the manifest only when the bytes still match the template (so
  # teardown can clean up an unedited copy automatically).
  if [ -f "$PROJECT_TARGET" ]; then
    if should_overwrite "$PROJECT_REL"; then
      cp "$PROJECT_TEMPLATE" "$PROJECT_TARGET"
      manifest_set_hash "$PROJECT_REL" "$(kit_sha256_file "$PROJECT_TARGET")"
      success "$PROJECT_REL (overwritten from template)"
      FRESH_PROJECT_MD=true
    else
      info "$PROJECT_REL (kept — your edits preserved)"
    fi
  else
    cp "$PROJECT_TEMPLATE" "$PROJECT_TARGET"
    manifest_set_hash "$PROJECT_REL" "$(kit_sha256_file "$PROJECT_TARGET")"
    success "$PROJECT_REL"
    FRESH_PROJECT_MD=true
  fi
}

# ---------------------------------------------------------------------------
# .gitignore (managed block at the end of the file — never touches user entries)
# ---------------------------------------------------------------------------
setup_gitignore() {
  header ".gitignore (managed block)"
  local file="$PROJECT_ROOT/.gitignore"
  local action="appended"

  if [ -f "$file" ] && agentic_gitignore_present "$file"; then
    if should_overwrite ".gitignore (managed block)"; then
      agentic_gitignore_strip "$file" >/dev/null 2>&1 || true
      action="refreshed"
    else
      info ".gitignore (managed block already present)"
      manifest_set_hash ".gitignore" "block:$(kit_sha256_string "$(agentic_gitignore_render)")"
      return 0
    fi
  elif [ ! -f "$file" ]; then
    action="created"
  fi

  if [ -s "$file" ]; then
    local last_byte
    last_byte=$(tail -c1 "$file" 2>/dev/null || true)
    [ "$last_byte" != $'\n' ] && printf '\n' >> "$file"
    printf '\n' >> "$file"
  fi
  agentic_gitignore_render >> "$file"
  manifest_set_hash ".gitignore" "block:$(kit_sha256_string "$(agentic_gitignore_render)")"
  case "$action" in
    refreshed) success ".gitignore (managed block refreshed)" ;;
    created)   success ".gitignore (created with managed block)" ;;
    *)         success ".gitignore (managed block appended)" ;;
  esac
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
printf "${BOLD}${CYAN}  │       agentic-kit           │${RESET}\n"
printf "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
info "project root: $PROJECT_ROOT"
info "kit location: $SUBMODULE_DIR/"
info "artefacts:    $ARTEFACTS_DIR_NAME/  (pipeline doc, project config, memory, features)"

if [ -z "$IDE_CHOICE" ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    printf "\n  Target IDE? [${BOLD}c${RESET}]laude  c${BOLD}[u]${RESET}rsor  co${BOLD}[p]${RESET}ilot  [${BOLD}a${RESET}]ll  (default: claude) "
    read -r -n1 ide_key
    printf '\n'
    case "$ide_key" in
      u|U) IDE_CHOICE="cursor" ;;
      p|P) IDE_CHOICE="github" ;;
      a|A|b|B) IDE_CHOICE="all" ;;
      *)   IDE_CHOICE="claude" ;;
    esac
  else
    IDE_CHOICE="claude"
  fi
fi

info "IDE mode: $IDE_CHOICE"

# Template drift detection: warn if PIPELINE.md.template changed since last init.
_cfg_file="$KIT_CFG"
if [ -f "$_cfg_file" ]; then
  _saved_sha=$(grep '^PIPELINE_SHA=' "$_cfg_file" 2>/dev/null | cut -d= -f2- || true)
  if [ -n "$_saved_sha" ]; then
    _current_sha=""
    if command -v sha256sum &>/dev/null; then
      _current_sha=$(sha256sum "$PIPELINE_TEMPLATE" | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
      _current_sha=$(shasum -a 256 "$PIPELINE_TEMPLATE" | awk '{print $1}')
    fi
    if [ -n "$_current_sha" ] && [ "$_current_sha" != "$_saved_sha" ]; then
      warn "PIPELINE.md.template has changed since last init."
      info "Review:  diff $PIPELINE_TARGET $PIPELINE_TEMPLATE"
      info "Refresh: $SUBMODULE_DIR/tools/init.sh --force"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Run setups
# ---------------------------------------------------------------------------
FRESH_PROJECT_MD=false

# Always set up the artefacts dir first — it is referenced by every IDE entry-point.
setup_artefacts_dir

case "$IDE_CHOICE" in
  claude)
    setup_claude
    ;;
  cursor)
    setup_cursor
    ;;
  github)
    setup_github
    ;;
  all)
    setup_claude
    setup_cursor
    setup_github
    ;;
  *)
    err "Invalid IDE mode '$IDE_CHOICE' (use claude, cursor, github, or all)"
    exit 1
    ;;
esac

setup_gitignore

# ---------------------------------------------------------------------------
# PROJECT.md autofill (CLI nudge or [AGENT ACTION REQUIRED] hint)
# ---------------------------------------------------------------------------
if [ "$FRESH_PROJECT_MD" = true ]; then
  header "$PROJECT_REL — fill in project-specific config"

  project_md_fill_prompt="Inspect this project's files (e.g. package.json, pyproject.toml, Makefile, Cargo.toml, go.mod — whatever exists) to infer the test command, build command, and any version files. Then fill in all the placeholder values in $PROJECT_REL and write the completed file. Only ask me if you genuinely cannot determine a value."

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
      AGENT_BIN=$(find_agent_bin 2>/dev/null) || AGENT_BIN=""
      if [ -n "$AGENT_BIN" ]; then
        fill_cli="agent"
        fill_label="Cursor Agent"
      fi
      ;;
    github|all)
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

  if $NON_INTERACTIVE; then
    # Agent / CI mode: do NOT spawn a nested agent process — the agent that invoked this
    # script should fill PROJECT.md itself using its own tools after init completes.
    printf "\n${BOLD}  [AGENT ACTION REQUIRED]${RESET} Fill in $PROJECT_REL\n"
    printf "  Inspect the project files (package.json, pyproject.toml, Cargo.toml, go.mod,\n"
    printf "  Makefile, etc.) to infer the test command, build command, and version files.\n"
    printf "  Replace every <placeholder> in $PROJECT_REL with the correct value.\n"
    printf "  Then run: ${SUBMODULE_DIR}/tools/validate-config.sh\n\n"
  else
    run_fill=false
    if [ -n "$fill_cli" ]; then
      if [ -t 0 ]; then
        printf '\n'
        printf "  Fill in ${BOLD}$PROJECT_REL${RESET} automatically using ${fill_label}? [${BOLD}Y${RESET}/n] "
        read -r yn; yn="${yn:-Y}"
        [[ "$yn" =~ ^[Yy]$ ]] && run_fill=true
      elif { : >/dev/tty; } 2>/dev/null; then
        printf '\n'
        printf "  Fill in ${BOLD}$PROJECT_REL${RESET} automatically using ${fill_label}? [${BOLD}Y${RESET}/n] " > /dev/tty
        read -r yn < /dev/tty; yn="${yn:-Y}"
        [[ "$yn" =~ ^[Yy]$ ]] && run_fill=true
      fi
    fi

    if $run_fill; then
      info "Running ${fill_label}..."
      case "$fill_cli" in
        claude)
          ( cd "$PROJECT_ROOT" && claude -p --allowedTools 'Edit,Write,Read,Glob,Grep,Bash' "$project_md_fill_prompt" )
          ;;
        agent)
          ( cd "$PROJECT_ROOT" && "$AGENT_BIN" -p --force "$project_md_fill_prompt" )
          ;;
      esac
      success "$PROJECT_REL filled in"
      info "Run ${SUBMODULE_DIR}/tools/validate-config.sh to verify."
    else
      if [ -n "$fill_cli" ] && [ ! -t 0 ]; then
        info "$PROJECT_REL auto-fill skipped (no TTY). Pass --non-interactive for agent/CI mode, or edit it manually."
      fi
      if [ -z "$fill_cli" ]; then
        case "$IDE_CHOICE" in
          claude)
            info "Claude CLI (\`claude\`) not on PATH — install Claude Code or fill $PROJECT_REL manually."
            ;;
          cursor)
            info "Cursor Agent CLI (\`agent\`) not on PATH — https://cursor.com/docs/cli/installation"
            info "(the desktop \`cursor\` launcher is Electron — not the same binary)."
            ;;
          github|all)
            info "Neither \`claude\` nor \`agent\` (Cursor Agent CLI) on PATH — install one or fill $PROJECT_REL manually."
            ;;
        esac
      fi
      info "Edit $PROJECT_REL → Project-Specific Configuration, then run:"
      info "${SUBMODULE_DIR}/tools/validate-config.sh"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Write .agentic-kit-artefacts/.agentic-kit.cfg (persist IDE choice + template sha for drift detection)
# ---------------------------------------------------------------------------
_pipeline_sha=""
if command -v sha256sum &>/dev/null; then
  _pipeline_sha=$(sha256sum "$PIPELINE_TEMPLATE" | awk '{print $1}')
elif command -v shasum &>/dev/null; then
  _pipeline_sha=$(shasum -a 256 "$PIPELINE_TEMPLATE" | awk '{print $1}')
fi
_kit_version=""
_kit_version=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || true)
{
  printf 'IDE=%s\n' "$IDE_CHOICE"
  printf 'INIT_DATE=%s\n' "$(date +%Y-%m-%d)"
  printf 'KIT_VERSION=%s\n' "$_kit_version"
  printf 'PIPELINE_SHA=%s\n' "$_pipeline_sha"
  printf 'ARTEFACTS_DIR=%s\n' "$ARTEFACTS_DIR_NAME"
} > "$KIT_CFG"

# ---------------------------------------------------------------------------
# Project probe (--tune): write .agentic-kit-artefacts/PROJECT_PROFILE.md so agents self-tune
# ---------------------------------------------------------------------------
if $TUNE; then
  _probe="$SCRIPT_DIR/tools/probe-project.sh"
  if [ -x "$_probe" ]; then
    info "Probing project to write $ARTEFACTS_DIR_NAME/PROJECT_PROFILE.md (--tune)…"
    _probe_args=( "--force" )
    if $NON_INTERACTIVE; then _probe_args+=( "--quick" ); fi
    if ! ( cd "$PROJECT_ROOT" && ARTEFACTS_DIR="$ARTEFACTS_DIR_NAME" "$_probe" "${_probe_args[@]}" ); then
      warn "probe-project.sh exited non-zero — PROJECT_PROFILE.md may be incomplete or missing."
    fi
  else
    info "probe-project.sh not found at $_probe — skipping --tune."
  fi
fi

# ---------------------------------------------------------------------------
# Memory tree: always initialise (idempotent, never overwrites entries)
# ---------------------------------------------------------------------------
_mem_init="$SCRIPT_DIR/tools/memory-init.sh"
if [ -x "$_mem_init" ]; then
  info "Initialising layered memory tree at $ARTEFACTS_DIR_NAME/memory/…"
  if ! ( cd "$PROJECT_ROOT" && ARTEFACTS_DIR="$ARTEFACTS_DIR_NAME" "$_mem_init" ); then
    warn "memory-init.sh exited non-zero — memory tree may be missing files. Re-run: $SUBMODULE_DIR/tools/memory-init.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  ✓ Done.${RESET}\n\n"
printf "  ${BOLD}Layout${RESET}\n"
printf "  ${DIM}%-38s${RESET} %s\n" "Pipeline doc:"      "${CYAN}$PIPELINE_REL${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Project config:"    "${CYAN}$PROJECT_REL${RESET}"
case "$IDE_CHOICE" in
  claude)
    printf "  ${DIM}%-38s${RESET} %s\n" "Entry point:" "${CYAN}CLAUDE.md${RESET} (managed include block)"
    ;;
  cursor)
    printf "  ${DIM}%-38s${RESET} %s\n" "Entry point:" "${CYAN}AGENTS.md${RESET} (managed include block)"
    ;;
  github)
    printf "  ${DIM}%-38s${RESET} %s\n" "Entry point:" "${CYAN}.github/copilot-instructions.md${RESET} (managed include block)"
    ;;
  all)
    printf "  ${DIM}%-38s${RESET} %s\n" "Entry points:" "${CYAN}CLAUDE.md, AGENTS.md, .github/copilot-instructions.md${RESET}"
    ;;
esac

printf "\n  ${BOLD}Next steps${RESET}\n"
case "$IDE_CHOICE" in
  claude)
    printf "  ${DIM}%-38s${RESET} %s\n" "Start a feature:" "${CYAN}/vadavik${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Check feature status:" "${CYAN}${SUBMODULE_DIR}/tools/feature-status.sh${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Validate config:" "${CYAN}${SUBMODULE_DIR}/tools/validate-config.sh${RESET}"
    ;;
  cursor)
    printf "  ${DIM}%-38s${RESET} %s\n" "Skills installed:" "${CYAN}.cursor/skills/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Subagents installed:" "${CYAN}.cursor/agents/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "After submodule update:" "${CYAN}${SUBMODULE_DIR}/tools/update.sh${RESET}"
    ;;
  github)
    printf "  ${DIM}%-38s${RESET} %s\n" "Agents installed:" "${CYAN}.github/agents/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Instructions installed:" "${CYAN}.github/instructions/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "After submodule update:" "${CYAN}${SUBMODULE_DIR}/tools/update.sh${RESET}"
    ;;
  all)
    printf "  ${DIM}%-38s${RESET} %s\n" "Claude Code — start a feature:" "${CYAN}/vadavik${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Cursor subagents:" "${CYAN}.cursor/agents/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "Copilot agents:" "${CYAN}.github/agents/${RESET}"
    printf "  ${DIM}%-38s${RESET} %s\n" "After submodule update:" "${CYAN}${SUBMODULE_DIR}/tools/update.sh${RESET}"
    ;;
esac

printf "\n  ${BOLD}Removal${RESET}\n"
printf "  ${DIM}%-38s${RESET} %s\n" "Strip kit:" "${CYAN}${SUBMODULE_DIR}/tools/teardown.sh${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Strip kit + remove submodule:" "${CYAN}${SUBMODULE_DIR}/tools/teardown.sh --remove-submodule${RESET}"
printf '\n'
