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
REMOVE=false
DRY_RUN="${DRY_RUN:-false}"
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=true ;;
    --remove)   REMOVE=true ;;
    --dry-run)  DRY_RUN=true ;;
  esac
done

SETTINGS_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

# Bash works everywhere (Git Bash on Windows, native on macOS/Linux).
# Use --powershell flag to force the PowerShell variant on Windows.
SL_COMMAND="bash ${SUBMODULE_DIR}/tools/statusline.sh"
for arg in "$@"; do
  case "$arg" in
    --powershell|--ps) SL_COMMAND="pwsh -NoProfile -File ${SUBMODULE_DIR}/tools/statusline.ps1" ;;
  esac
done

# Check if jq is available
if ! command -v jq &>/dev/null; then
  if $REMOVE; then
    warn "jq not found — remove the statusLine entry from $SETTINGS_FILE manually."
    exit 0
  fi
  err "jq is required but not found on PATH."
  err "Install: https://jqlang.github.io/jq/download/"
  exit 1
fi

# Remove only the kit's own statusLine (a command pointing at tools/statusline.*).
# A user's custom statusLine is left untouched.
if $REMOVE; then
  [ -f "$SETTINGS_FILE" ] || { info "no .claude/settings.json — nothing to remove"; exit 0; }
  has_sl=$(jq -r 'has("statusLine")' "$SETTINGS_FILE" 2>/dev/null || echo false)
  if [ "$has_sl" != "true" ]; then skip "statusLine not present in .claude/settings.json"; exit 0; fi
  is_ours=$(jq -r '((.statusLine.command // "") | (contains("tools/statusline.sh") or contains("tools/statusline.ps1")))' \
            "$SETTINGS_FILE" 2>/dev/null || echo false)
  if [ "$is_ours" != "true" ]; then skip "statusLine is not the kit's — leaving it untouched"; exit 0; fi
  if [ "$DRY_RUN" = "true" ]; then info "would remove the kit statusLine from $SETTINGS_FILE"; exit 0; fi
  jq 'del(.statusLine)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  removed "statusLine from .claude/settings.json"
  exit 0
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
