#!/usr/bin/env bash
# Runs the project test command and extracts a coverage summary for the handoff to Bahnik.
# Usage: .claude/skills/laznik/check-coverage.sh [feature-path]
# Run from project root.

set -euo pipefail

FEATURE_PATH="${1:-}"
PROJECT_MD="${PROJECT_MD:-PROJECT.md}"

if [ ! -f "$PROJECT_MD" ]; then
  echo "Error: $PROJECT_MD not found. Run from project root." >&2
  exit 1
fi

# Read test command from PROJECT.md
TEST_CMD=$(grep -m1 'Test command:' "$PROJECT_MD" | sed 's/.*Test command:[[:space:]]*//' | tr -d '`*')

if [ -z "$TEST_CMD" ] || [[ "$TEST_CMD" == *"<"* ]]; then
  echo "Error: Test command not configured in PROJECT.md (still has placeholder)." >&2
  exit 1
fi

echo "Running: $TEST_CMD"
echo "---"

# Run tests and capture output (exit code captured separately so set -e doesn't abort us)
OUTPUT=$(eval "$TEST_CMD" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

echo "$OUTPUT"
echo "---"

# Write summary to feature handoff-log if feature path provided
if [ -n "$FEATURE_PATH" ] && [ -d "$FEATURE_PATH" ]; then
  TIMESTAMP=$(date +%H:%M)
  LOG="$FEATURE_PATH/handoff-log.md"
  {
    echo ""
    echo "## $TIMESTAMP Laznik → Bahnik [test gate]"
    echo "Exit code: $EXIT_CODE"
    # Try to extract a summary line (works for Jest, pytest, vitest, go test)
    SUMMARY=$(echo "$OUTPUT" | grep -Ei '(tests?|specs?|pass|fail|error|ok)[^$]*$' | tail -3 || true)
    if [ -n "$SUMMARY" ]; then
      echo "Coverage summary:"
      echo "$SUMMARY" | sed 's/^/  /'
    fi
    echo "Artifacts: $FEATURE_PATH/tech-plan.md"
  } >> "$LOG"
  echo "Appended coverage summary to $LOG"
fi

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Tests FAILED (exit $EXIT_CODE). Do not hand off to Bahnik yet — fix failures first."
  exit $EXIT_CODE
else
  echo ""
  echo "Tests PASSED. Safe to hand off to Bahnik."
fi
