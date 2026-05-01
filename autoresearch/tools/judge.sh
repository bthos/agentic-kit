#!/usr/bin/env bash
# LLM-as-judge: scores one (requirement, output) pair as 0 or 1.
# Usage:
#   judge.sh --requirement-file <path> --output-file <path>
#   judge.sh --requirement "..." --output "..."
#
# Defaults to `claude -p` (Haiku-class model). Override via PROJECT.md:
#   - **Judge command:** `<your CLI>` (must accept stdin and emit one char on stdout)
# Run from project root.

set -euo pipefail

req=""
out=""
req_file=""
out_file=""

while [ $# -gt 0 ]; do
  case "$1" in
    --requirement)        req="$2"; shift 2 ;;
    --requirement-file)   req_file="$2"; shift 2 ;;
    --output)             out="$2"; shift 2 ;;
    --output-file)        out_file="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$req_file" ] && req=$(cat "$req_file")
[ -n "$out_file" ] && out=$(cat "$out_file")

if [ -z "$req" ] || [ -z "$out" ]; then
  echo "Provide both requirement and output (--requirement[-file] / --output[-file])." >&2
  exit 2
fi

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
JUDGE_TEMPLATE="$KIT_DIR/judge.md"

if [ ! -f "$JUDGE_TEMPLATE" ]; then
  echo "judge.md not found at $JUDGE_TEMPLATE — autoresearch loop is not initialised." >&2
  exit 2
fi

# Substitute placeholders
prompt=$(awk -v req="$req" -v out="$out" '
  {
    line=$0
    gsub(/\{\{requirement\}\}/, req, line)
    gsub(/\{\{output\}\}/, out, line)
    print line
  }
' "$JUDGE_TEMPLATE")

# Resolve judge command:
#   1) PROJECT.md  →  - **Judge command:** `<cmd>`
#   2) `claude -p --allowedTools ''`
JUDGE_CMD=""
if [ -f "PROJECT.md" ]; then
  JUDGE_CMD=$(grep -E '^\s*-\s+\*\*Judge command:\*\*' PROJECT.md 2>/dev/null \
              | sed -E 's/^[^`]*`([^`]+)`.*/\1/' | head -n1 || true)
fi

if [ -z "$JUDGE_CMD" ]; then
  if command -v claude &>/dev/null; then
    JUDGE_CMD="claude -p --allowedTools ''"
  else
    echo "No judge command available (no PROJECT.md override and no claude CLI)." >&2
    exit 2
  fi
fi

# Run judge: prompt is passed via stdin
verdict=$(printf '%s\n' "$prompt" | eval "$JUDGE_CMD" 2>/dev/null | tr -d '[:space:]' | head -c 1)

case "$verdict" in
  0|1) echo "$verdict" ;;
  *)   echo "0" ;;  # Per program.md rule 5: uncertainty = failure
esac
