#!/usr/bin/env bash
# Pull the latest agentic-kit submodule revision, then re-run init with the
# same flags you use day-to-day. The pipeline doc, project config, and any
# kit-managed include blocks (CLAUDE.md / AGENTS.md / .github/copilot-instructions.md)
# are refreshed in place — your edits outside the marked blocks are preserved.
#
# Usage (from project root):
#   agentic-kit/tools/update.sh
#   agentic-kit/tools/update.sh --ide=cursor --skip
#   agentic-kit/tools/update.sh --non-interactive --ide=all
#
# Flags:
#   --no-pull   Skip `git submodule update --remote` (only run init.sh —
#               e.g. submodule already updated)
#
# Any other arguments are passed through to init.sh unchanged.
#
# After this script, commit the new submodule pointer if you want the team on
# the same kit version:
#   git add agentic-kit && git commit -m "chore: update agentic-kit"

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

kit_migrate_legacy_root_state

show_update_help() {
  cat <<'EOF'
agentic-kit / update.sh

  Pull the latest agentic-kit submodule revision, then re-run init.sh with the
  same flags you use day-to-day. The pipeline doc, project config, and any
  kit-managed include blocks are refreshed in place — your edits outside the
  marked blocks are preserved.

  USAGE
    agentic-kit/tools/update.sh [--no-pull] [INIT_FLAGS…]

  FLAGS
    --no-pull            Skip `git submodule update --remote` (re-run init only).
    --help, -h           Show this help and exit.

    Any other argument is forwarded to init.sh unchanged. Common ones:
      --ide=claude|cursor|github|all
      --non-interactive, -n, --yes, -y
      --skip-all | --overwrite-all | --force
      --tune | --no-tune

  AFTER UPDATE
    git add agentic-kit && git commit -m "chore: update agentic-kit"
EOF
}

PULL=true
has_ide_arg=false
forward_args=()
for arg in "$@"; do
  case "$arg" in
    --help|-h) show_update_help; exit 0 ;;
    --no-pull) PULL=false ;;
    --ide=*) has_ide_arg=true; forward_args+=("$arg") ;;
    *) forward_args+=("$arg") ;;
  esac
done

# Read saved IDE from .artefacts/.agentic-kit.cfg if --ide not explicitly passed.
if ! $has_ide_arg; then
  _cfg="$KIT_CFG"
  if [ -f "$_cfg" ]; then
    _saved_ide=$(grep '^IDE=' "$_cfg" 2>/dev/null | cut -d= -f2- || true)
    if [ -n "$_saved_ide" ]; then
      forward_args+=("--ide=$_saved_ide")
      info "Using saved IDE from $ARTEFACTS_DIR_NAME/.agentic-kit.cfg: $_saved_ide"
    fi
  fi
fi

printf "\n"
printf "${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
printf "${BOLD}${CYAN}  │     agentic-kit update      │${RESET}\n"
printf "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
printf "\n"
info "project root: $PROJECT_ROOT"
info "submodule:    $SUBMODULE_DIR/"
info "artefacts:    $ARTEFACTS_DIR_NAME/  (PIPELINE.md will be refreshed; PROJECT.md kept)"

cd "$PROJECT_ROOT"

if $PULL; then
  header "git submodule update --remote"
  if ! git submodule update --remote "$SUBMODULE_DIR"; then
    err "git submodule update --remote failed (exit $?)."
    info "If the submodule is not initialised: git submodule update --init $SUBMODULE_DIR"
    info "If you do not use a tracking branch, update the pointer manually then run:"
    info "  $SUBMODULE_DIR/tools/init.sh  (same flags as usual: --ide=, --skip, etc.)"
    exit 1
  fi
  success "$SUBMODULE_DIR"
else
  header "Submodule pull"
  info "Skipped (--no-pull)"
fi

# Drift check: warn if the canonical pipeline copy is out of sync with the
# submodule template (init.sh refreshes it, but a heads-up makes the upcoming
# overwrite less surprising).
PIPELINE_CANONICAL="$ARTEFACTS_DIR/PIPELINE.md"
PIPELINE_TEMPLATE="$SCRIPT_DIR/templates/PIPELINE.md.template"
if [ -f "$PIPELINE_CANONICAL" ] && [ -f "$PIPELINE_TEMPLATE" ]; then
  _have=$(kit_sha256_file "$PIPELINE_CANONICAL" || true)
  _want=$(kit_sha256_file "$PIPELINE_TEMPLATE" || true)
  if [ -n "$_have" ] && [ -n "$_want" ] && [ "$_have" != "$_want" ]; then
    info "Pipeline drift detected — $ARTEFACTS_DIR_NAME/PIPELINE.md will be refreshed by init.sh."
    info "Diff:    diff $ARTEFACTS_DIR_NAME/PIPELINE.md $SUBMODULE_DIR/templates/PIPELINE.md.template"
  fi
fi

exec "$SCRIPT_DIR/tools/init.sh" "${forward_args[@]}"
