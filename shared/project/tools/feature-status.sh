#!/usr/bin/env bash
# Shows pipeline status for all active features in .tlk/features/.
# Usage: talaka/shared/project/tools/feature-status.sh  (from project root)
# Run from project root.

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
FEATURES_DIR="$ARTEFACTS/features"
ARCHIVE_DIR="$ARTEFACTS/archive"

check() {
  local label="$1"
  local path="$2"
  if [ -e "$path" ]; then
    echo "  ✓ $label"
    return 0
  else
    echo "  ✗ $label"
    return 1
  fi
}

suggest_next() {
  local dir="$1"
  if [ ! -f "$dir/spec.md" ];        then echo "  → Next: /eliciting-requirements (write spec)"; return; fi
  if [ ! -f "$dir/ux-design.md" ];   then echo "  → Next: /designing-ux (UX design)"; return; fi
  if [ ! -f "$dir/tech-plan.md" ];   then echo "  → Next: /planning-architecture (arch + tests)"; return; fi
  echo "  → Check handoff-log.md for current state"
}

last_activity() {
  local log="$1/handoff-log.md"
  [ -f "$log" ] || return
  local last_line
  last_line=$(grep '^## ' "$log" 2>/dev/null | tail -1 || true)
  [ -n "$last_line" ] && echo "  last: $last_line"
}

if [ ! -d "$FEATURES_DIR" ]; then
  echo "No active features ($FEATURES_DIR/ does not exist)."
  echo "Start one with: /eliciting-requirements"
  exit 0
fi

found=0
for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue
  found=$((found + 1))
  name=$(basename "$feature_dir")
  echo "$name"
  check "spec.md"         "$feature_dir/spec.md"        || true
  check "ux-design.md"    "$feature_dir/ux-design.md"   || true
  check "tech-plan.md"    "$feature_dir/tech-plan.md"   || true
  check "handoff-log.md"  "$feature_dir/handoff-log.md" || true
  check "LESSONS.md"      "$feature_dir/LESSONS.md"     || true
  # Deferred decisions count
  if [ -f "$feature_dir/deferred.md" ]; then
    open_count=$(grep -c '^\- \*\*Status:\*\* open$' "$feature_dir/deferred.md" 2>/dev/null || true)
    if [ "${open_count:-0}" -gt 0 ]; then
      echo "  ⚠ $open_count deferred decision(s) open"
    fi
  fi
  last_activity "$feature_dir" || true
  suggest_next "$feature_dir"
  echo ""
done

if [ $found -eq 0 ]; then
  echo "No active features in $FEATURES_DIR"
  echo "Start one with: /eliciting-requirements"
fi

if [ -d "$ARCHIVE_DIR" ]; then
  archived=$(find "$ARCHIVE_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "$archived" -gt 0 ] && echo "$archived archived feature(s) in $ARCHIVE_DIR"
fi
