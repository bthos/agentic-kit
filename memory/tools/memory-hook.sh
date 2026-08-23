#!/usr/bin/env bash
# Install or remove the talaka memory maintenance hook in
# .claude/settings.json. The hook runs `memory/tools/tick.sh` (promote +
# rollover) when a Claude Code session or subagent stops, so the memory tree
# stays fresh without a cron job.
#
# Usage:
#   talaka/memory/tools/memory-hook.sh                 # install (idempotent)
#   talaka/memory/tools/memory-hook.sh --remove        # remove the kit's hook
#   talaka/memory/tools/memory-hook.sh --event SubagentStop   # default: Stop
#   talaka/memory/tools/memory-hook.sh --dry-run
#
# Only the kit's own hook entry (identified by the tick.sh command) is touched —
# any other hooks you have configured are preserved. Requires jq.
#
# Run from the project root (or let init.sh / teardown.sh call it).

set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../../shared/lifecycle/tools/lib.sh
source "$(cd "$_TOOLS_DIR/../../shared/lifecycle/tools" && pwd)/lib.sh"

REMOVE=false
DRY_RUN="${DRY_RUN:-false}"
EVENT="Stop"
for arg in "$@"; do
  case "$arg" in
    --remove)    REMOVE=true ;;
    --dry-run)   DRY_RUN=true ;;
    --event)     ;;                      # handled below (needs the next token)
    --event=*)   EVENT="${arg#--event=}" ;;
    -h|--help)   sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done
# Support "--event Stop" (space-separated) too.
_prev=""
for arg in "$@"; do
  [ "$_prev" = "--event" ] && EVENT="$arg"
  _prev="$arg"
done

SETTINGS_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
MARKER="memory/tools/tick.sh"
HOOK_CMD="bash ${SUBMODULE_DIR}/memory/tools/tick.sh >/dev/null 2>&1 || true"

# jq is required; without it we cannot safely edit JSON. Degrade gracefully (the
# hook is opt-in) with a clear manual instruction rather than failing the caller.
if ! command -v jq &>/dev/null; then
  if $REMOVE; then
    warn "jq not found — remove the \"$MARKER\" hook from $SETTINGS_FILE manually."
  else
    warn "jq not found — cannot install the memory hook automatically."
    info "Install jq, or add a Stop hook running \`$HOOK_CMD\` to $SETTINGS_FILE."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Remove
# ---------------------------------------------------------------------------
if $REMOVE; then
  [ -f "$SETTINGS_FILE" ] || { info "no .claude/settings.json — nothing to remove"; exit 0; }

  # Does our hook exist under any event?
  present=$(jq --arg m "$MARKER" '
    [ (.hooks // {}) | to_entries[] | .value[]? | (.hooks // [])[]? | (.command // "") | contains($m) ] | any
  ' "$SETTINGS_FILE" 2>/dev/null || echo false)
  if [ "$present" != "true" ]; then
    skip "memory hook not present in .claude/settings.json"
    exit 0
  fi
  if [ "$DRY_RUN" = "true" ]; then
    info "would remove the memory hook ($MARKER) from $SETTINGS_FILE"
    exit 0
  fi

  jq --arg m "$MARKER" '
    # Drop any hook-group (under every event) that runs our command.
    if (.hooks | type) == "object" then
      .hooks |= ( to_entries
        | map( .value |= map( select( ((.hooks // []) | map((.command // "") | contains($m)) | any) | not ) ) )
        | map( select( (.value | length) > 0 ) )   # drop now-empty event arrays
        | from_entries )
    else . end
    | if (.hooks // {}) == {} then del(.hooks) else . end
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
  removed "memory hook ($MARKER) from .claude/settings.json"
  exit 0
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
mkdir -p "$SETTINGS_DIR"

if [ -f "$SETTINGS_FILE" ]; then
  already=$(jq --arg m "$MARKER" '
    [ (.hooks // {}) | to_entries[] | .value[]? | (.hooks // [])[]? | (.command // "") | contains($m) ] | any
  ' "$SETTINGS_FILE" 2>/dev/null || echo false)
  if [ "$already" = "true" ]; then
    skip "memory hook already configured in .claude/settings.json"
    exit 0
  fi
  if [ "$DRY_RUN" = "true" ]; then
    info "would add a $EVENT hook running \`$HOOK_CMD\` to $SETTINGS_FILE"
    exit 0
  fi
  jq --arg ev "$EVENT" --arg cmd "$HOOK_CMD" '
    .hooks //= {} |
    .hooks[$ev] //= [] |
    .hooks[$ev] += [ { hooks: [ { type: "command", command: $cmd } ] } ]
  ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  if [ "$DRY_RUN" = "true" ]; then
    info "would create $SETTINGS_FILE with a $EVENT memory hook"
    exit 0
  fi
  jq -n --arg ev "$EVENT" --arg cmd "$HOOK_CMD" '
    { hooks: { ($ev): [ { hooks: [ { type: "command", command: $cmd } ] } ] } }
  ' > "$SETTINGS_FILE"
fi
success "memory $EVENT hook configured → $HOOK_CMD"
info "Runs promote + rollover when a session/subagent stops. Remove with: $SUBMODULE_DIR/memory/tools/memory-hook.sh --remove"
