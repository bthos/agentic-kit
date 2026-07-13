#!/usr/bin/env bash
# Creates a new investigation folder under .tlk/debug/ with today's date prefix.
# Usage: .claude/skills/bugs-diagnosing/new-investigation.sh <slug>
# Example: .claude/skills/bugs-diagnosing/new-investigation.sh login-stuck-spinner
# Run from project root.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <slug>" >&2
  echo "Example: $0 login-stuck-spinner" >&2
  exit 1
fi

SLUG="$1"
DATE=$(date +%Y-%m-%d)
ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
INV_DIR="$ARTEFACTS/debug/${DATE}-${SLUG}"
INV_ID="${DATE}-${SLUG}"

# Locate template directory — supports both kit-submodule path and installed-skill path.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/templates" ]; then
  TPL="$SCRIPT_DIR/templates"
elif [ -d "talaka/skills/bugs-diagnosing/templates" ]; then
  TPL="talaka/skills/bugs-diagnosing/templates"
else
  echo "ERROR: cannot locate bugs-diagnosing templates dir" >&2
  exit 2
fi

if [ -d "$INV_DIR" ]; then
  echo "Investigation folder already exists: $INV_DIR"
  echo "INVESTIGATION_PATH=$INV_DIR"
  echo "INVESTIGATION_ID=$INV_ID"
  exit 0
fi

mkdir -p "$INV_DIR"

# Render templates with simple substitution.
for f in hypothesis instrumentation-log findings handoff-log; do
  if [ -f "$TPL/${f}.md" ]; then
    sed -e "s|{{SLUG}}|${SLUG}|g" \
        -e "s|{{DATE}}|${DATE}|g" \
        -e "s|{{INVESTIGATION_ID}}|${INV_ID}|g" \
        "$TPL/${f}.md" > "$INV_DIR/${f}.md"
  fi
done

echo "Created: $INV_DIR"
echo "  hypothesis.md          (fill before instrumenting)"
echo "  instrumentation-log.md (agent appends observations)"
echo "  findings.md            (root cause + handoff to Cmok)"
echo "  handoff-log.md         (handoff entries)"
echo ""
echo "INVESTIGATION_PATH=$INV_DIR"
echo "INVESTIGATION_ID=$INV_ID"
