#!/usr/bin/env bash
# Creates a new consistency-audit folder under .tlk/audits/ with today's date prefix.
# Usage: .claude/skills/consistency-auditing/new-audit.sh <slug>
# Example: .claude/skills/consistency-auditing/new-audit.sh model-naming
# Run from project root.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <slug>" >&2
  echo "Example: $0 model-naming" >&2
  exit 1
fi

SLUG="$1"
DATE=$(date +%Y-%m-%d)
ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
AUDIT_DIR="$ARTEFACTS/audits/${DATE}-${SLUG}"
AUDIT_ID="${DATE}-${SLUG}"

# Locate template directory — supports both kit-submodule path and installed-skill path.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/templates" ]; then
  TPL="$SCRIPT_DIR/templates"
elif [ -d "talaka/skills/consistency-auditing/templates" ]; then
  TPL="talaka/skills/consistency-auditing/templates"
else
  echo "ERROR: cannot locate consistency-auditing templates dir" >&2
  exit 2
fi

if [ -d "$AUDIT_DIR" ]; then
  echo "Audit folder already exists: $AUDIT_DIR"
  echo "AUDIT_PATH=$AUDIT_DIR"
  echo "AUDIT_ID=$AUDIT_ID"
  exit 0
fi

mkdir -p "$AUDIT_DIR"

# Render templates with simple substitution.
for f in audit handoff-log; do
  if [ -f "$TPL/${f}.md" ]; then
    sed -e "s|{{SLUG}}|${SLUG}|g" \
        -e "s|{{DATE}}|${DATE}|g" \
        -e "s|{{AUDIT_ID}}|${AUDIT_ID}|g" \
        "$TPL/${f}.md" > "$AUDIT_DIR/${f}.md"
  fi
done

echo "Created: $AUDIT_DIR"
echo "  audit.md       (ranked findings + recommended fix per finding)"
echo "  handoff-log.md (handoff entries)"
echo ""
echo "AUDIT_PATH=$AUDIT_DIR"
echo "AUDIT_ID=$AUDIT_ID"
