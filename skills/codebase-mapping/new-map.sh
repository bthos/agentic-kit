#!/usr/bin/env bash
# Creates a new codebase-map folder under .tlk/maps/ with today's date prefix.
# Usage: .claude/skills/codebase-mapping/new-map.sh <slug>
# Example: .claude/skills/codebase-mapping/new-map.sh payments-service
# Run from project root.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <slug>" >&2
  echo "Example: $0 payments-service" >&2
  exit 1
fi

SLUG="$1"
DATE=$(date +%Y-%m-%d)
ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"
MAP_DIR="$ARTEFACTS/maps/${DATE}-${SLUG}"
MAP_ID="${DATE}-${SLUG}"

# Locate template directory — supports both kit-submodule path and installed-skill path.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/templates" ]; then
  TPL="$SCRIPT_DIR/templates"
elif [ -d "talaka/skills/codebase-mapping/templates" ]; then
  TPL="talaka/skills/codebase-mapping/templates"
else
  echo "ERROR: cannot locate codebase-mapping templates dir" >&2
  exit 2
fi

if [ -d "$MAP_DIR" ]; then
  echo "Map folder already exists: $MAP_DIR"
  echo "MAP_PATH=$MAP_DIR"
  echo "MAP_ID=$MAP_ID"
  exit 0
fi

mkdir -p "$MAP_DIR"

# Render templates with simple substitution.
for f in map open-questions handoff-log; do
  if [ -f "$TPL/${f}.md" ]; then
    sed -e "s|{{SLUG}}|${SLUG}|g" \
        -e "s|{{DATE}}|${DATE}|g" \
        -e "s|{{MAP_ID}}|${MAP_ID}|g" \
        "$TPL/${f}.md" > "$MAP_DIR/${f}.md"
  fi
done

echo "Created: $MAP_DIR"
echo "  map.md            (structured codebase map — fill this in)"
echo "  open-questions.md (unknowns surfaced for the user / next role)"
echo "  handoff-log.md    (workers append return entries here)"
echo ""
echo "MAP_PATH=$MAP_DIR"
echo "MAP_ID=$MAP_ID"
