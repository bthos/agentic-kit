#!/usr/bin/env bash
# Append a row to <feature>/metrics.jsonl AND to
# agentic-kit/autoresearch/runs/cost.jsonl (so Veles has fleet-wide history).
#
# Usage:
#   record-metrics.sh \
#     --feature .artefacts/features/2026-04-30-foo \
#     --agent cmok \
#     --tokens 18432 \
#     --wall-ms 91500 \
#     [--accuracy 0.83] \
#     [--variant baseline] \
#     [--cost-per-min 0.02] \
#     [--cost-per-token 0.000003]
#
# Anything missing is recorded as null. Run from project root.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNS_DIR="$KIT_DIR/runs"
COST_LOG="$RUNS_DIR/cost.jsonl"
mkdir -p "$RUNS_DIR"

feature=""
agent=""
tokens="null"
wall_ms="null"
accuracy="null"
variant="baseline"
cost_per_min="${COST_PER_MIN:-0.02}"
cost_per_tok="${COST_PER_TOKEN:-0.000003}"

while [ $# -gt 0 ]; do
  case "$1" in
    --feature)        feature="$2"; shift 2 ;;
    --agent)          agent="$2"; shift 2 ;;
    --tokens)         tokens="$2"; shift 2 ;;
    --wall-ms)        wall_ms="$2"; shift 2 ;;
    --accuracy)       accuracy="$2"; shift 2 ;;
    --variant)        variant="$2"; shift 2 ;;
    --cost-per-min)   cost_per_min="$2"; shift 2 ;;
    --cost-per-token) cost_per_tok="$2"; shift 2 ;;
    -h|--help)        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$feature" ] || { echo "--feature required" >&2; exit 2; }
[ -n "$agent" ]   || { echo "--agent required"   >&2; exit 2; }

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
run_id=$(printf '%s_%s' "$ts" "$RANDOM")

# Compute cost (USD); skip if no numeric inputs
cost_usd="null"
if [ "$tokens" != "null" ] || [ "$wall_ms" != "null" ]; then
  awk_in=$(awk -v t="$tokens" -v w="$wall_ms" -v cm="$cost_per_min" -v ct="$cost_per_tok" '
    BEGIN {
      tt = (t == "null" ? 0 : t)
      ww = (w == "null" ? 0 : w)
      printf "%.6f", (ww/1000.0/60.0)*cm + tt*ct
    }
  ')
  cost_usd="$awk_in"
fi

json_line=$(printf '{"ts":"%s","run_id":"%s","feature":"%s","agent":"%s","variant":"%s","tokens":%s,"wall_ms":%s,"cost_usd":%s,"accuracy":%s}' \
  "$ts" "$run_id" "$feature" "$agent" "$variant" "$tokens" "$wall_ms" "$cost_usd" "$accuracy")

# Per-feature metrics file
mkdir -p "$feature"
printf '%s\n' "$json_line" >> "$feature/metrics.jsonl"

# Fleet-wide cost log
printf '%s\n' "$json_line" >> "$COST_LOG"

echo "$json_line"
