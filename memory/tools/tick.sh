#!/usr/bin/env bash
# Convenience "memory tick": run the promotion state machine and the rollover
# pass in one call. Intended for an idle/Stop hook or a daily cron so L3/L4 stay
# fresh and stale L1/L2 gets compacted without anyone remembering to run them.
#
# Note: log.sh already runs promote.sh on every write, so the main reason to run
# tick.sh is the time-based rollover (24h SESSION clear, 7-day L2 compaction).
#
# Usage:
#   memory/tools/tick.sh            # promote + rollover
#   memory/tools/tick.sh --dry-run  # show what each would do
#
# Override the artefacts directory with $ARTEFACTS_DIR (default: .akt).
# Run from project root.
#
# Example Claude Code hook (.claude/settings.json) — opt-in, add via /update-config:
#   {
#     "hooks": {
#       "Stop": [
#         { "hooks": [ { "type": "command",
#           "command": "agentic-kit/memory/tools/tick.sh >/dev/null 2>&1 || true" } ] }
#       ]
#     }
#   }

set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTEFACTS="${ARTEFACTS_DIR:-.akt}"

DRY=""
[ "${1:-}" = "--dry-run" ] && DRY="--dry-run"

if [ ! -d "$ARTEFACTS/memory" ]; then
  echo "Memory tree not initialised — run: agentic-kit/memory/tools/init.sh" >&2
  exit 0
fi

ARTEFACTS_DIR="$ARTEFACTS" bash "$SELF_DIR/promote.sh"  $DRY
ARTEFACTS_DIR="$ARTEFACTS" bash "$SELF_DIR/rollover.sh" $DRY
