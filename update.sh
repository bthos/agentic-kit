#!/usr/bin/env bash
# Pull the latest agentic-kit submodule revision, then re-run init with the same flags you use day-to-day.
#
# Usage (from project root):
#   .agentic-kit/update.sh
#   .agentic-kit/update.sh --ide=cursor --skip
#   .agentic-kit/update.sh --non-interactive --ide=all
#
# Flags:
#   --no-pull   Skip `git submodule update --remote` (only run init.sh — e.g. submodule already updated)
#
# Any other arguments are passed through to init.sh unchanged.
#
# After this script, commit the new submodule pointer if you want the team on the same kit version:
#   git add .agentic-kit && git commit -m "chore: update agentic-kit"

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PULL=true
has_ide_arg=false
forward_args=()
for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=false ;;
    --ide=*) has_ide_arg=true; forward_args+=("$arg") ;;
    *) forward_args+=("$arg") ;;
  esac
done

# Read saved IDE from .agentic-kit.cfg if --ide not explicitly passed.
if ! $has_ide_arg; then
  _cfg="$KIT_CFG"
  if [ -f "$_cfg" ]; then
    _saved_ide=$(grep '^IDE=' "$_cfg" 2>/dev/null | cut -d= -f2- || true)
    if [ -n "$_saved_ide" ]; then
      forward_args+=("--ide=$_saved_ide")
      info "Using saved IDE from .agentic-kit.cfg: $_saved_ide"
    fi
  fi
fi

printf "\n${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
printf "${BOLD}${CYAN}  │     agentic-kit update      │${RESET}\n"
printf "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
info "project root: $PROJECT_ROOT"
info "submodule:    $SUBMODULE_DIR/"

cd "$PROJECT_ROOT"

if $PULL; then
  header "git submodule update --remote"
  if ! git submodule update --remote "$SUBMODULE_DIR"; then
    err "git submodule update --remote failed."
    info "If the submodule is not initialised: git submodule update --init $SUBMODULE_DIR"
    info "If you do not use a tracking branch, update the pointer manually then run:"
    info "  .$SUBMODULE_DIR/init.sh  (same flags as usual: --ide=, --skip, etc.)"
    exit 1
  fi
  success "$SUBMODULE_DIR"
else
  header "Submodule pull"
  info "Skipped (--no-pull)"
fi

exec "$SCRIPT_DIR/init.sh" "${forward_args[@]}"
