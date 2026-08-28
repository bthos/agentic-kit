#!/usr/bin/env bash
# Append a row to <feature>/metrics.jsonl AND to
# .tlk/autoresearch/runs/cost.jsonl (so Veles has fleet-wide history).
#
# Installed from talaka/templates/autoresearch/tools/ by run.sh --init.
# Edit this copy freely — the kit template is never overwritten after first install.
#
# Usage:
#   .tlk/autoresearch/tools/record-metrics.sh \
#     --feature .tlk/features/2026-04-30-foo \
#     --agent cmok \
#     --tokens 18432 \
#     --wall-ms 91500 \
#     [--accuracy 0.83] \
#     [--variant baseline] \
#     [--cost-per-min 0.02] \
#     [--cost-per-token 0.000003]
#
# --feature must name a directory that already exists. A bare slug
# (2026-04-30-foo) is resolved against .tlk/features, .tlk/archive and
# .tlk/audits; a .tlk/features/<slug> path whose feature has already been
# archived falls back to .tlk/archive/<slug>. An unresolvable --feature is an
# error — the row is never written to a freshly created directory.
#
# Anything missing is recorded as null. Run from project root.

set -euo pipefail

# Enable verbose tracing if VERBOSE=1 or DEBUG=1
if [ "${VERBOSE:-}" = "1" ] || [ "${DEBUG:-}" = "1" ]; then
  export PS4='+ $(date -u "+%Y-%m-%dT%H:%M:%SZ")\040 '
  set -x
fi

# If LOG_FILE set, redirect stdout+stderr to the file (append)
if [ -n "${LOG_FILE:-}" ]; then
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || true
  exec 1> >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
fi

PROJECT_ROOT="$(pwd)"
ARTEFACTS="${ARTEFACTS_DIR:-$PROJECT_ROOT/.tlk}"
RUNS_DIR="$ARTEFACTS/autoresearch/runs"
COST_LOG="$RUNS_DIR/cost.jsonl"
mkdir -p "$ARTEFACTS" "$RUNS_DIR"

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
    --log-file=*) LOG_FILE="${1#--log-file=}"; shift ;;
    --log-file) LOG_FILE="${2:-}"; shift 2 ;;
    -h|--help)        sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$feature" ] || { echo "--feature required" >&2; exit 2; }
[ -n "$agent" ]   || { echo "--agent required"   >&2; exit 2; }

# ---------------------------------------------------------------------------
# Resolve --feature to a directory that already exists.
#
# The old code ran `mkdir -p "$feature"` unconditionally, so any path the caller
# invented — a bare slug, a typo, a stale relative path — was created on the
# spot and the row was orphaned there (issue #3). Resolution now has to succeed
# against something on disk; otherwise we refuse to write.
#
#   1. the path as given, if it is a directory
#   2. archive race: .tlk/features/<slug> already moved to .tlk/archive/<slug>
#   3. bare slug: look it up under the known artefact roots
# ---------------------------------------------------------------------------
resolved=""
if [ -d "$feature" ]; then
  resolved="$feature"
else
  archived="${feature/\/features\//\/archive\/}"
  if [ "$archived" != "$feature" ] && [ -d "$archived" ]; then
    echo "record-metrics: '$feature' not found — feature already archived; appending to '$archived'" >&2
    resolved="$archived"
  else
    # Prefer a project-relative artefacts prefix so an auto-prefixed slug is
    # recorded as ".tlk/features/<slug>" — the same string agents pass — rather
    # than an absolute path that would split this run off in fleet aggregation.
    art_prefix="$ARTEFACTS"
    case "$ARTEFACTS" in
      "$PROJECT_ROOT"/*) art_prefix="${ARTEFACTS#"$PROJECT_ROOT"/}" ;;
    esac
    for candidate in "$art_prefix/features/$feature" "$art_prefix/archive/$feature" "$art_prefix/audits/$feature"; do
      [ -d "$candidate" ] || continue
      resolved="$candidate"
      break
    done
  fi
fi

if [ -z "$resolved" ]; then
  {
    echo "record-metrics: --feature '$feature' does not resolve to an existing directory."
    echo "  Tried: '$feature', its /archive/ counterpart, and"
    echo "         ${art_prefix:-$ARTEFACTS}/{features,archive,audits}/$feature"
    echo "  Pass a real feature path (e.g. .tlk/features/<slug>) — refusing to create it,"
    echo "  because an invented path orphans this row where nothing will ever read it."
  } >&2
  exit 2
fi
feature="$resolved"

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
run_id=$(printf '%s_%s' "$ts" "$RANDOM")

# Compute cost (USD); skip if no numeric inputs
cost_usd="null"
if [ "$tokens" != "null" ] || [ "$wall_ms" != "null" ]; then
  cost_usd=$(awk -v t="$tokens" -v w="$wall_ms" -v cm="$cost_per_min" -v ct="$cost_per_tok" '
    BEGIN {
      tt = (t == "null" ? 0 : t)
      ww = (w == "null" ? 0 : w)
      printf "%.6f", (ww/1000.0/60.0)*cm + tt*ct
    }
  ')
fi

json_line=$(printf '{"ts":"%s","run_id":"%s","feature":"%s","agent":"%s","variant":"%s","tokens":%s,"wall_ms":%s,"cost_usd":%s,"accuracy":%s}' \
  "$ts" "$run_id" "$feature" "$agent" "$variant" "$tokens" "$wall_ms" "$cost_usd" "$accuracy")

# Per-feature metrics file. $feature is already resolved to an existing
# directory above, so this only ever appends inside a real feature/archive/audit
# folder — no mkdir, no orphans.
printf '%s\n' "$json_line" >> "$feature/metrics.jsonl"

# Fleet-wide cost log
printf '%s\n' "$json_line" >> "$COST_LOG"

echo "$json_line"
echo "record-metrics: appended to $feature/metrics.jsonl and $COST_LOG" >&2
