#!/usr/bin/env bash
# Install the agentic-kit statusline into the target project's .claude/settings.json.
# Idempotent: skips if statusLine is already configured.
#
# Usage: agentic-kit/tools/install-statusline.sh [--force]
#   --force   Overwrite an existing statusLine entry
#
# Requires: jq

set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$_TOOLS_DIR/lib.sh"

FORCE=false
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=true ;;
  esac
done

SETTINGS_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# Detect OS and pick the right statusline command
case "$(uname -s 2>/dev/null || echo Windows)" in
  MINGW*|MSYS*|CYGWIN*|Windows*|windows*)
    SL_COMMAND="pwsh -NoProfile -File ${SUBMODULE_DIR}/tools/statusline.ps1"
    ;;
  *)
    SL_COMMAND="bash ${SUBMODULE_DIR}/tools/statusline.sh"
    ;;
esac

# Check if jq is available
if ! command -v jq &>/dev/null; then
  err "jq is required but not found on PATH."
  err "Install: https://jqlang.github.io/jq/download/"
  exit 1
fi

mkdir -p "$SETTINGS_DIR"

if [ -f "$SETTINGS_FILE" ]; then
  # Check for existing statusLine config
  HAS_SL=$(jq -r 'has("statusLine")' "$SETTINGS_FILE" 2>/dev/null || echo "false")
  if [ "$HAS_SL" = "true" ] && ! $FORCE; then
    skip "statusLine already configured in .claude/settings.json (use --force to overwrite)"
    exit 0
  fi

  # Merge statusLine into existing settings
  jq --arg cmd "$SL_COMMAND" '.statusLine = { type: "command", command: $cmd, refreshInterval: 10 }' \
    "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  # Create fresh settings.json with statusLine
  jq -n --arg cmd "$SL_COMMAND" '{ statusLine: { type: "command", command: $cmd, refreshInterval: 10 } }' \
    > "$SETTINGS_FILE"
fi

success "statusLine configured → $SL_COMMAND"
info "Refresh interval: 10s (keeps pipeline stage current during idle)"
