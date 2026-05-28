#!/usr/bin/env bash
# Run from the target project root after adding the submodule.
# Usage: agentic-kit/tools/init.sh [--force | --overwrite-all | --skip | --skip-all | --non-interactive]
#
# What this script does (minimally invasive by design):
#
#   1.  Creates `.akt/` and copies the canonical pipeline doc + project config:
#         .akt/PIPELINE.md   (kit-managed; refreshed on update)
#         .akt/PROJECT.md    (you edit; kept on update)
#
#   2.  Installs agents (.claude/agents/) and skills (.claude/skills/) from the
#       kit submodule. SHA-256 of every installed file is recorded in
#       .akt/.agentic-kit.files so teardown.sh refuses to delete paths you have
#       edited locally.
#
#   3.  Adds a managed include block to (or creates) the entry-point files:
#         CLAUDE.md   (read natively by Claude Code)
#         AGENTS.md   (the cross-IDE convention — read by any workspace-aware tool)
#       Block delimiters: <!-- agentic-kit:start --> ... <!-- agentic-kit:end -->
#       Existing user content above/below the markers is preserved verbatim.
#
#   4.  Adds a managed block to .gitignore for ephemeral state under
#         .akt/{memory,features,archive,proposed-patches,scratch} plus
#         .akt/.agentic-kit.cfg and .akt/.agentic-kit.files
#       PIPELINE.md and PROJECT.md inside .akt/ are NOT ignored — your team
#       should commit them.
#
# Flags:
#   --force, --overwrite-all   Overwrite all existing kit-managed paths without prompting
#   --skip, --skip-all         Skip every existing path without prompting
#   --non-interactive, -n      Agent / CI mode: no prompts, skip existing files, emit
#                              [AGENT ACTION REQUIRED] instruction to fill PROJECT.md
#                              (aliases: --yes, -y)
#
# Interactive conflict prompt: [s]kip this  [o]verwrite this  overwrite [a]ll  skip [r]est

set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$_TOOLS_DIR/lib.sh"
# shellcheck source=install-helpers.sh
source "$_TOOLS_DIR/install-helpers.sh"

kit_migrate_legacy_root_state

# Canonical project-local locations (after migration from .artefacts/)
PIPELINE_REL="$ARTEFACTS_NAME/PIPELINE.md"
PROJECT_REL="$ARTEFACTS_NAME/PROJECT.md"
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

  Bootstrap agentic-kit in the current project (run from project root).

  USAGE
    agentic-kit/tools/init.sh [--force | --overwrite-all | --skip | --skip-all]
                              [--non-interactive | -n | --yes | -y]
                              [--tune | --no-tune]
                              [--help | -h]

  WHAT IT DOES
    1. Writes .akt/PIPELINE.md (canonical pipeline) and .akt/PROJECT.md
       (project-specific config; you fill in placeholders).
    2. Copies agents to .claude/agents/ and skills to .claude/skills/.
    3. Adds a managed include block to CLAUDE.md and AGENTS.md, both pointing
       at .akt/PIPELINE.md. Existing user content is preserved verbatim.
    4. Adds a managed block to .gitignore for ephemeral state.

  CROSS-IDE
    Claude Code reads CLAUDE.md natively. Any other workspace-aware IDE picks
    up AGENTS.md (the cross-IDE convention). One install covers all of them.

  OPTIONS
    --non-interactive, -n   Agent / CI mode: no prompts, accept all defaults,
                            skip existing files, and print [AGENT ACTION REQUIRED]
                            instead of spawning a nested AI process.
                            Aliases: --yes, -y.

    --skip, --skip-all      Skip every existing path without prompting.
                            (automatic when stdin is not a TTY)

    --force, --overwrite-all
                            Overwrite all existing kit-managed files without prompting.

    --with-autoresearch     Set up the autoresearch metrics system (eval-set,
                            program.md, record-metrics.sh). If autoresearch is
                            already initialised, always refreshes without prompting.
    --no-autoresearch       Skip autoresearch setup even if already initialised.

    --tune                  After install, probe the project (stack, frameworks,
                            test/build commands, conventions) and write
                            .akt/PROJECT_PROFILE.md so agents can self-tune.
                            Calls `agentic-kit/tools/probe-project.sh --force`.
    --no-tune               Skip the probe step (default).

    --help, -h              Show this help and exit.

  INTERACTIVE CONFLICT PROMPT
    When a managed path already exists:
      s  skip this file
      o  overwrite this file
      a  overwrite all remaining files
      r  skip rest (this file and every later conflict)
      d  show diff (current vs. incoming) — only when both are plain files

  AGENT INVOCATION
    agentic-kit/tools/init.sh --non-interactive

    After the script exits, read the [AGENT ACTION REQUIRED] block in the output
    and fill in .akt/PROJECT.md yourself (inspect package.json, pyproject.toml,
    Cargo.toml, go.mod, Makefile, etc.), then run:
      agentic-kit/tools/validate-config.sh

  EXAMPLES
    agentic-kit/tools/init.sh                          # interactive
    agentic-kit/tools/init.sh --non-interactive        # CI / agent
    agentic-kit/tools/init.sh --skip-all               # keep all existing kit paths

EOF
}

# ---------------------------------------------------------------------------
# Conflict resolution (init-only)
# ---------------------------------------------------------------------------
OVERWRITE_ALL=false
SKIP_ALL=false
ask_conflict() {
  local label="$1"
  local current="${2:-}"   # existing file path (for diff)
  local incoming="${3:-}"  # new/kit file path (for diff)
  if $OVERWRITE_ALL; then return 0; fi
  if $SKIP_ALL; then return 1; fi
  if [ ! -t 0 ]; then return 1; fi
  local _can_diff=false
  [ -n "$current" ] && [ -n "$incoming" ] && [ -f "$current" ] && [ -f "$incoming" ] && _can_diff=true
  while true; do
    printf "  ${YELLOW}exists${RESET} %s — " "$label"
    if $_can_diff; then
      printf "[${BOLD}s${RESET}]kip  [${BOLD}o${RESET}]verwrite  overwrite [${BOLD}a${RESET}]ll  skip [${BOLD}r${RESET}]est  [${BOLD}d${RESET}]iff  "
    else
      printf "[${BOLD}s${RESET}]kip  [${BOLD}o${RESET}]verwrite  overwrite [${BOLD}a${RESET}]ll  skip [${BOLD}r${RESET}]est  "
    fi
    read -r -n1 choice
    printf '\n'
    case "$choice" in
      o|O) return 0 ;;
      a|A) OVERWRITE_ALL=true; return 0 ;;
      r|R) SKIP_ALL=true; return 1 ;;
      s|S|"") return 1 ;;
      d|D) $_can_diff && diff -u "$current" "$incoming" || true ;;
      *) ;;
    esac
  done
}

MODE=""
NON_INTERACTIVE=false
TUNE=false
AUTORESEARCH=""  # "yes" | "no" | "" (auto-detect)

for arg in "$@"; do
  case "$arg" in
    --help|-h)                       show_help; exit 0 ;;
    --force|--overwrite-all)         MODE="force" ;;
    --skip|--skip-all)               MODE="skip" ;;
    --non-interactive|-n|--yes|-y)   NON_INTERACTIVE=true ;;
    --ide=*)
      err "--ide=* was removed; agentic-kit now installs a single Claude-shaped layout."
      err "Cursor, GitHub Copilot and other workspace-aware IDEs read AGENTS.md."
      err "See CHANGELOG.md. Re-run without --ide=."
      exit 2
      ;;
    --tune)                          TUNE=true ;;
    --no-tune)                       TUNE=false ;;
    --with-autoresearch)             AUTORESEARCH="yes" ;;
    --no-autoresearch)               AUTORESEARCH="no" ;;
  esac
done

# No args + no TTY → agent discovered the script; show help so it knows what to pass next.
if [ $# -eq 0 ] && [ ! -t 0 ] && [ ! -t 1 ]; then
  show_help
  exit 0
fi

# --non-interactive implies skip-existing (safe default: don't overwrite without being asked)
if $NON_INTERACTIVE && [ -z "$MODE" ]; then MODE="skip"; fi

if [ "$MODE" = "force" ]; then OVERWRITE_ALL=true; fi

should_overwrite() {
  local label="$1"
  local current="${2:-}"
  local incoming="${3:-}"
  if [ "$MODE" = "skip" ]; then
    skip "$label (use --force or --overwrite-all to overwrite)"
    return 1
  fi
  if $SKIP_ALL; then
    skip "$label (skip rest)"
    return 1
  fi
  ask_conflict "$label" "$current" "$incoming"
}

# install_kit_copy_file and install_kit_copy_tree live in install-helpers.sh.

# ---------------------------------------------------------------------------
# Managed include block — entry-point files (CLAUDE.md and AGENTS.md)
#
# Behaviour matrix:
#   file missing                → write a small stub with the include block
#   file present, block missing → append the block (existing content kept)
#   file present, block present → leave as-is unless --force, then refresh block
# ---------------------------------------------------------------------------
install_pipeline_include() {
  local label="$1" dest_rel="$2"
  local dest="$PROJECT_ROOT/$dest_rel"
  local block_sha

  if [ -f "$dest" ]; then
    if agentic_block_present "$dest"; then
      if should_overwrite "$label"; then
        agentic_block_strip "$dest" >/dev/null 2>&1 || true
        agentic_block_append "$dest" "$PIPELINE_REL"
        block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL")")
        manifest_set_hash "$dest_rel" "block:$block_sha"
        success "$label (block refreshed)"
      else
        block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL")")
        manifest_set_hash "$dest_rel" "block:$block_sha"
        info "$label (block already present — manifest synced)"
      fi
    else
      agentic_block_append "$dest" "$PIPELINE_REL"
      block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL")")
      manifest_set_hash "$dest_rel" "block:$block_sha"
      success "$label (block appended; existing content preserved)"
    fi
    return 0
  fi

  agentic_block_write_stub "$dest" "$PIPELINE_REL"
  block_sha=$(kit_sha256_string "$(agentic_block_render "$PIPELINE_REL")")
  manifest_set_hash "$dest_rel" "stub:$(kit_sha256_file "$dest")"
  success "$label (created with include block)"
}

# ---------------------------------------------------------------------------
# Claude-shaped skill install (.claude/skills/<name>/)
# ---------------------------------------------------------------------------
link_claude_skills() {
  header "Skills (.claude/skills/)"

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

# ---------------------------------------------------------------------------
# Main setup: agents + skills + entry-point files
# ---------------------------------------------------------------------------
setup_kit() {
  header "Agents (.claude/agents/)"

  local agent name rel
  for agent in "$SCRIPT_DIR/agents/"*.md; do
    [ -e "$agent" ] || continue
    name=$(basename "$agent")
    rel=".claude/agents/$name"
    install_kit_copy_file ".claude/agents/$name" "$rel" "$agent" || true
  done

  link_claude_skills

  header "Entry-point files (managed include blocks)"
  install_pipeline_include "CLAUDE.md" "CLAUDE.md"
  install_pipeline_include "AGENTS.md" "AGENTS.md"
}

# ---------------------------------------------------------------------------
# .akt/ (canonical home for PIPELINE.md and PROJECT.md)
# ---------------------------------------------------------------------------
setup_artefacts_dir() {
  header "$ARTEFACTS_NAME/ (pipeline + project config)"
  mkdir -p "$ARTEFACTS"

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
kit_banner "agentic-kit"
info "project root: $PROJECT_ROOT"
info "kit location: $SUBMODULE_DIR/"
info "artefacts:    $ARTEFACTS_NAME/  (pipeline doc, project config, memory, features)"

# Template drift detection: warn if PIPELINE.md.template changed since last init.
_saved_sha=$(kit_cfg_get PIPELINE_SHA 2>/dev/null || true)
if [ -n "$_saved_sha" ]; then
  _current_sha=$(kit_sha256_file "$PIPELINE_TEMPLATE" 2>/dev/null || true)
  if [ -n "$_current_sha" ] && [ "$_current_sha" != "$_saved_sha" ]; then
    warn "PIPELINE.md.template has changed since last init."
    info "Review:  diff $PIPELINE_TARGET $PIPELINE_TEMPLATE"
    info "Refresh: $SUBMODULE_DIR/tools/init.sh --force"
  fi
fi

# ---------------------------------------------------------------------------
# Run setups — wrapped in a manifest transaction so all SHA updates land in one
# atomic write at the end (instead of rewriting .agentic-kit.files per entry).
# ---------------------------------------------------------------------------
FRESH_PROJECT_MD=false

manifest_begin
trap 'manifest_abort; _kit_cleanup_temps' ERR

# Always set up the artefacts dir first — it is referenced by the entry-point files.
setup_artefacts_dir

setup_kit

setup_gitignore

manifest_commit
trap _kit_cleanup_temps EXIT

# ---------------------------------------------------------------------------
# PROJECT.md autofill (CLI nudge or [AGENT ACTION REQUIRED] hint)
# ---------------------------------------------------------------------------
if [ "$FRESH_PROJECT_MD" = true ]; then
  header "$PROJECT_REL — fill in project-specific config"

  project_md_fill_prompt="Inspect this project's files (e.g. package.json, pyproject.toml, Makefile, Cargo.toml, go.mod — whatever exists) to infer the test command, build command, and any version files. Then fill in all the placeholder values in $PROJECT_REL and write the completed file. Only ask me if you genuinely cannot determine a value."

  fill_cli=""
  if command -v claude &>/dev/null; then
    fill_cli="claude"
  fi

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
        printf "  Fill in ${BOLD}$PROJECT_REL${RESET} automatically using Claude? [${BOLD}Y${RESET}/n] "
        read -r yn; yn="${yn:-Y}"
        [[ "$yn" =~ ^[Yy]$ ]] && run_fill=true
      elif { : >/dev/tty; } 2>/dev/null; then
        printf '\n'
        printf "  Fill in ${BOLD}$PROJECT_REL${RESET} automatically using Claude? [${BOLD}Y${RESET}/n] " > /dev/tty
        read -r yn < /dev/tty; yn="${yn:-Y}"
        [[ "$yn" =~ ^[Yy]$ ]] && run_fill=true
      fi
    fi

    if $run_fill; then
      info "Running Claude..."
      ( cd "$PROJECT_ROOT" && claude -p --allowedTools 'Edit,Write,Read,Glob,Grep,Bash' "$project_md_fill_prompt" )
      success "$PROJECT_REL filled in"
      info "Run ${SUBMODULE_DIR}/tools/validate-config.sh to verify."
    else
      if [ -n "$fill_cli" ] && [ ! -t 0 ]; then
        info "$PROJECT_REL auto-fill skipped (no TTY). Pass --non-interactive for agent/CI mode, or edit it manually."
      fi
      if [ -z "$fill_cli" ]; then
        info "Claude CLI (\`claude\`) not on PATH — install Claude Code or fill $PROJECT_REL manually."
      fi
      info "Edit $PROJECT_REL → Project-Specific Configuration, then run:"
      info "${SUBMODULE_DIR}/tools/validate-config.sh"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Write .akt/.agentic-kit.cfg (persist template sha + kit version + resolved
# paths so other tools/agents can read them without re-running discovery).
# ---------------------------------------------------------------------------
_pipeline_sha=$(kit_sha256_file "$PIPELINE_TEMPLATE" 2>/dev/null || true)
_kit_version=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || true)

kit_cfg_set_many \
  INIT_DATE       "$(date +%Y-%m-%d)" \
  KIT_VERSION     "$_kit_version" \
  PIPELINE_SHA    "$_pipeline_sha" \
  ARTEFACTS_DIR   "$ARTEFACTS_NAME" \
  KIT_ROOT        "$SCRIPT_DIR" \
  PROJECT_ROOT    "$PROJECT_ROOT" \
  SUBMODULE_DIR   "$SUBMODULE_DIR"

# ---------------------------------------------------------------------------
# Project probe (--tune): write .akt/PROJECT_PROFILE.md so agents self-tune
# ---------------------------------------------------------------------------
if $TUNE; then
  _probe="$SCRIPT_DIR/tools/probe-project.sh"
  if [ -x "$_probe" ]; then
    info "Probing project to write $ARTEFACTS_NAME/PROJECT_PROFILE.md (--tune)…"
    _probe_args=( "--force" )
    if $NON_INTERACTIVE; then _probe_args+=( "--quick" ); fi
    if ! ( cd "$PROJECT_ROOT" && ARTEFACTS_DIR="$ARTEFACTS_NAME" "$_probe" "${_probe_args[@]}" ); then
      warn "probe-project.sh exited non-zero — PROJECT_PROFILE.md may be incomplete or missing."
    fi
  else
    info "probe-project.sh not found at $_probe — skipping --tune."
  fi
fi

# ---------------------------------------------------------------------------
# Memory tree: always initialise (idempotent, never overwrites entries)
# ---------------------------------------------------------------------------
_mem_init="$SCRIPT_DIR/memory/tools/init.sh"
if [ -x "$_mem_init" ]; then
  info "Initialising layered memory tree at $ARTEFACTS_NAME/memory/…"
  if ! ( cd "$PROJECT_ROOT" && ARTEFACTS_DIR="$ARTEFACTS_NAME" "$_mem_init" ); then
    warn "memory/tools/init.sh exited non-zero — memory tree may be missing files. Re-run: $SUBMODULE_DIR/memory/tools/init.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Autoresearch: metrics system (eval-set, program.md, record-metrics.sh)
# ---------------------------------------------------------------------------
_ar_run="$SCRIPT_DIR/autoresearch/run.sh"
_ar_program="$ARTEFACTS/autoresearch/program.md"
_ar_setup=false

if [ "$AUTORESEARCH" = "yes" ]; then
  _ar_setup=true
elif [ "$AUTORESEARCH" = "no" ]; then
  _ar_setup=false
elif [ -f "$_ar_program" ]; then
  # Already initialised — always refresh (idempotent)
  _ar_setup=true
else
  # Not initialised and no explicit flag — ask the user
  if $NON_INTERACTIVE; then
    info "Autoresearch not initialised (pass --with-autoresearch to enable)"
  elif [ -t 0 ]; then
    printf '\n'
    printf "  Set up ${BOLD}autoresearch${RESET} metrics system (eval-set + Veles ratchet)? [y/${BOLD}N${RESET}] "
    read -r yn; yn="${yn:-N}"
    [[ "$yn" =~ ^[Yy]$ ]] && _ar_setup=true
  fi
fi

if $_ar_setup && [ -x "$_ar_run" ]; then
  header "Autoresearch (metrics system)"
  if ( cd "$PROJECT_ROOT" && ARTEFACTS_DIR="$ARTEFACTS_NAME" "$_ar_run" --init ); then
    success "Autoresearch initialised at $ARTEFACTS_NAME/autoresearch/"
  else
    warn "autoresearch/run.sh --init exited non-zero."
    info "Re-run: $SUBMODULE_DIR/autoresearch/run.sh --init"
  fi
elif $_ar_setup && [ ! -x "$_ar_run" ]; then
  warn "autoresearch/run.sh not found at $_ar_run — skipping."
fi

# ---------------------------------------------------------------------------
# Statusline: pipeline-aware status bar for Claude Code
# ---------------------------------------------------------------------------
_sl_install="$SCRIPT_DIR/tools/install-statusline.sh"
if [ -x "$_sl_install" ]; then
  info "Configuring pipeline-aware statusline…"
  if ! ( cd "$PROJECT_ROOT" && "$_sl_install" ); then
    warn "install-statusline.sh exited non-zero — statusline not configured."
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  ✓ Done.${RESET}\n\n"
printf "  ${BOLD}Layout${RESET}\n"
printf "  ${DIM}%-38s${RESET} %s\n" "Pipeline doc:"      "${CYAN}$PIPELINE_REL${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Project config:"    "${CYAN}$PROJECT_REL${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Entry points:"      "${CYAN}CLAUDE.md, AGENTS.md${RESET} (managed include blocks)"
printf "  ${DIM}%-38s${RESET} %s\n" "Agents installed:"  "${CYAN}.claude/agents/${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Skills installed:"  "${CYAN}.claude/skills/${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Statusline:"        "${CYAN}.claude/settings.json (statusLine)${RESET}"

printf "\n  ${BOLD}Next steps${RESET}\n"
printf "  ${DIM}%-38s${RESET} %s\n" "Start a feature:"       "${CYAN}/vadavik${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Check feature status:"  "${CYAN}${SUBMODULE_DIR}/tools/feature-status.sh${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Validate config:"       "${CYAN}${SUBMODULE_DIR}/tools/validate-config.sh${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "After submodule update:" "${CYAN}${SUBMODULE_DIR}/tools/update.sh${RESET}"

printf "\n  ${BOLD}Removal${RESET}\n"
printf "  ${DIM}%-38s${RESET} %s\n" "Strip kit:" "${CYAN}${SUBMODULE_DIR}/tools/teardown.sh${RESET}"
printf "  ${DIM}%-38s${RESET} %s\n" "Strip kit + remove submodule:" "${CYAN}${SUBMODULE_DIR}/tools/teardown.sh --remove-submodule${RESET}"
printf '\n'
