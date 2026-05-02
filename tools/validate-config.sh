#!/usr/bin/env bash
# Checks PROJECT.md for unfilled Project-Specific Configuration placeholders.
# Usage: agentic-kit/tools/validate-config.sh  (from project root)
# Run from project root. Exits non-zero if any placeholders remain.

set -euo pipefail

PROJECT_MD="${PROJECT_MD:-.agentic-kit-artefacts/PROJECT.md}"

if [ ! -f "$PROJECT_MD" ]; then
  echo "Error: $PROJECT_MD not found. Run from project root." >&2
  exit 1
fi

errors=0

check_field() {
  local label="$1"
  local value
  value=$(grep -m1 "$label" "$PROJECT_MD" | sed "s/.*${label}[[:space:]]*//" | tr -d '`*' | xargs)

  if [ -z "$value" ] || [[ "$value" == *"<"* ]]; then
    echo "  MISSING  $label  (got: ${value:-empty})"
    errors=$((errors + 1))
  else
    echo "  OK       $label  → $value"
  fi
}

warn_field() {
  local label="$1"
  local value
  value=$(grep -m1 "$label" "$PROJECT_MD" | sed "s/.*${label}[[:space:]]*//" | tr -d '`*' | xargs)

  if [ -z "$value" ] || [[ "$value" == *"<"* ]]; then
    echo "  WARN     $label  (still a placeholder — agents will have less context)"
  else
    echo "  OK       $label  → $value"
  fi
}

echo "Validating $PROJECT_MD..."
echo ""
echo "Required fields:"
check_field "Test command:"
check_field "Build command:"
check_field "Version files:"
echo ""
echo "Optional fields (warn only):"
warn_field "What it is:"
warn_field "Tech stack:"
warn_field "Key conventions:"
echo ""

if [ $errors -gt 0 ]; then
  echo "Fix $errors missing field(s) in $PROJECT_MD before running the pipeline."
  exit 1
else
  echo "Configuration OK."
fi
