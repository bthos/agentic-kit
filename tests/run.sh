#!/usr/bin/env bash
# Test runner for talaka. Discovers and executes every *.test.sh under
# tests/ (each in its own bash process for isolation) plus the legacy
# memory/tools/test-search-parity.sh smoke test.
#
# Usage:
#   tests/run.sh                 # run everything
#   tests/run.sh memory          # only files whose path matches "memory"
#   tests/run.sh promote rollover
#
# Exit status is non-zero if any test file fails.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

if [ -t 1 ]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_RED=''; C_BOLD=''; C_DIM=''; C_RESET=''
fi

# Collect test files (sorted, stable).
mapfile -t all_files < <(find "$TESTS_DIR" -name '*.test.sh' -type f | LC_ALL=C sort)

# Legacy standalone smoke test — run it too.
parity="$KIT_ROOT/memory/tools/test-search-parity.sh"
[ -f "$parity" ] && all_files+=( "$parity" )

# Optional filter args.
files=()
if [ "$#" -gt 0 ]; then
  for f in "${all_files[@]}"; do
    for pat in "$@"; do
      case "$f" in *"$pat"*) files+=( "$f" ); break;; esac
    done
  done
else
  files=( "${all_files[@]}" )
fi

if [ "${#files[@]}" -eq 0 ]; then
  echo "No test files matched." >&2
  exit 1
fi

files_passed=0
files_failed=0
failed_files=()

printf '%s%stalaka test suite%s  (%d file(s))\n' "$C_BOLD" "" "$C_RESET" "${#files[@]}"
printf '%sbash %s · %s%s\n\n' "$C_DIM" "${BASH_VERSION%%(*}" "$(uname -s 2>/dev/null || echo unknown)" "$C_RESET"

for f in "${files[@]}"; do
  rel="${f#"$KIT_ROOT"/}"
  printf '%s▸ %s%s\n' "$C_BOLD" "$rel" "$C_RESET"
  if bash "$f"; then
    files_passed=$((files_passed + 1))
  else
    files_failed=$((files_failed + 1))
    failed_files+=( "$rel" )
  fi
  echo
done

printf '%s════════════════════════════════════════%s\n' "$C_DIM" "$C_RESET"
if [ "$files_failed" -eq 0 ]; then
  printf '%sAll %d test file(s) passed.%s\n' "$C_GREEN" "$files_passed" "$C_RESET"
  exit 0
else
  printf '%s%d file(s) failed:%s\n' "$C_RED" "$files_failed" "$C_RESET"
  for f in "${failed_files[@]}"; do printf '  %s✗ %s%s\n' "$C_RED" "$f" "$C_RESET"; done
  printf '%s%d file(s) passed.%s\n' "$C_GREEN" "$files_passed" "$C_RESET"
  exit 1
fi
