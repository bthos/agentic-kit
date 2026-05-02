#!/usr/bin/env bash
# Rolls L1 (SESSION-STATE.md) and old L2 daily files when they go stale.
#
#   - Empties the "In-flight decisions" section of SESSION-STATE.md if mtime > 24h.
#   - Compacts L2 daily files older than 7 days into a weekly summary stub
#     (memory-promote.sh will re-promote anything that survives the 2-strike rule
#     before the file ages out, so compaction is safe).
#
# Usage:
#   agentic-kit/tools/memory-rollover.sh
#   agentic-kit/tools/memory-rollover.sh --dry-run
#
# Run from project root, ideally as a daily cron / hook.

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.agentic-kit-artefacts}"
MEM_DIR="$ARTEFACTS/memory"
SESSION="$ARTEFACTS/SESSION-STATE.md"

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

if [ -f "$SESSION" ]; then
  if find "$SESSION" -mmin +1440 2>/dev/null | grep -q .; then
    if $DRY_RUN; then
      echo "  (dry-run) would clear In-flight decisions in $SESSION (>24h stale)"
    else
      python3 - "$SESSION" <<'PY' 2>/dev/null || true
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")
new = re.sub(
    r"## In-flight decisions[\s\S]*?(?=\n## |\Z)",
    "## In-flight decisions\n_(empty — auto-cleared by memory-rollover.sh)_\n\n",
    src, count=1)
if new != src: p.write_text(new, encoding="utf-8")
PY
      echo "  cleared In-flight decisions in $SESSION"
    fi
  fi
fi

if [ -d "$MEM_DIR" ]; then
  cutoff=$(date -d "-7 days" +%Y-%m-%d 2>/dev/null \
           || date -v-7d +%Y-%m-%d 2>/dev/null \
           || python3 -c "import datetime; print((datetime.date.today()-datetime.timedelta(days=7)).isoformat())")
  for f in "$MEM_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    if [[ "$name" < "$cutoff" ]]; then
      if [ ! -f "$f.compact" ]; then
        if $DRY_RUN; then
          echo "  (dry-run) would compact $f (older than $cutoff)"
        else
          {
            echo "# Daily memory — $name (compacted)"
            echo
            echo "_Compacted by memory-rollover.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Original retained as $name.md.compact._"
            echo
            grep -E '^- id: ' "$f" | head -n 20 || true
          } > "$f.compact.tmp"
          mv "$f" "$f.compact"
          mv "$f.compact.tmp" "$f"
          echo "  compacted $f (preserved at $f.compact)"
        fi
      fi
    fi
  done
fi

echo "Rollover done."
