#!/usr/bin/env bash
# Creates a new pattern-adaptation feature folder under .tlk/features/ (adapt- prefix).
# Usage: .claude/skills/patterns-adapting/new-adaptation.sh <slug>
# Example: .claude/skills/patterns-adapting/new-adaptation.sh llm-wiki
# Run from project root.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <slug>" >&2
  echo "Example: $0 llm-wiki" >&2
  exit 1
fi

SLUG="$1"
DATE=$(date +%Y-%m-%d)
ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
FEATURE_DIR="$ARTEFACTS/features/${DATE}-adapt-${SLUG}"
ADAPT_ID="${DATE}-adapt-${SLUG}"

# Locate template directory — supports both kit-submodule path and installed-skill path.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/templates" ]; then
  TPL="$SCRIPT_DIR/templates"
elif [ -d "talaka/skills/patterns-adapting/templates" ]; then
  TPL="talaka/skills/patterns-adapting/templates"
else
  echo "ERROR: cannot locate patterns-adapting templates dir" >&2
  exit 2
fi

if [ -d "$FEATURE_DIR" ]; then
  echo "Adaptation folder already exists: $FEATURE_DIR"
  echo "FEATURE_PATH=$FEATURE_DIR"
  echo "ADAPT_ID=$ADAPT_ID"
  exit 0
fi

mkdir -p "$FEATURE_DIR"

# Render templates with simple substitution.
for f in research-brief adaptation handoff-log; do
  if [ -f "$TPL/${f}.md" ]; then
    sed -e "s|{{SLUG}}|${SLUG}|g" \
        -e "s|{{DATE}}|${DATE}|g" \
        -e "s|{{ADAPT_ID}}|${ADAPT_ID}|g" \
        "$TPL/${f}.md" > "$FEATURE_DIR/${f}.md"
  fi
done

echo "Created: $FEATURE_DIR"
echo "  research-brief.md (source provenance + extracted core insight)"
echo "  adaptation.md     (how the pattern maps onto this project's conventions)"
echo "  handoff-log.md    (handoff entries)"
echo ""
echo "FEATURE_PATH=$FEATURE_DIR"
echo "ADAPT_ID=$ADAPT_ID"
