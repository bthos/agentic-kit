#!/usr/bin/env bash
# Checks PROJECT.md for unfilled Project-Specific Configuration placeholders.
# Usage: tools/validate-config.sh
# Run from project root. Exits non-zero if any placeholders remain.

set -euo pipefail

PROJECT_MD="${PROJECT_MD:-PROJECT.md}"

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

echo "Validating $PROJECT_MD..."
echo ""
check_field "Test command:"
check_field "Build command:"
check_field "Version files:"
echo ""

if [ $errors -gt 0 ]; then
  echo "Fix $errors missing field(s) in $PROJECT_MD before running the pipeline."
  exit 1
else
  echo "Configuration OK."
fi
