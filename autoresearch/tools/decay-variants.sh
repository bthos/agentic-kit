#!/usr/bin/env bash
# Decays Навь: prunes variant snapshots under .tlk/autoresearch/variants/ that are
# older than the retention window (default 90 days). This is the ONLY sanctioned
# way to delete variant history — Veles never prunes inline during a ratchet round.
#
# Each pruned round is appended to runs/decay.jsonl BEFORE removal, so the audit
# trail (which round, how old, why removed) outlives the bulky snapshot itself.
#
# Usage:
#   decay-variants.sh                 # prune round dirs older than 90 days
#   decay-variants.sh --days 30       # custom retention window
#   decay-variants.sh --dry-run       # list what would be pruned, delete nothing
#
# Run from project root.
#
# Environment:
#   ARTEFACTS_DIR  Path to the project artefacts folder (default: .tlk)

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

VARIANTS_DIR="$ARTEFACTS/autoresearch/variants"
RUNS_DIR="$ARTEFACTS/autoresearch/runs"
DECAY_LOG="$RUNS_DIR/decay.jsonl"

DAYS=90
DRY_RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose)    export VERBOSE=1; shift ;;
    --days=*)     DAYS="${1#--days=}"; shift ;;
    --days)       DAYS="${2:-}"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    --log-file=*) LOG_FILE="${1#--log-file=}"; shift ;;
    --log-file)   LOG_FILE="${2:-}"; shift 2 ;;
    -h|--help)    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Retention window must be a non-negative integer (days).
case "$DAYS" in
  ''|*[!0-9]*) echo "--days must be a non-negative integer (got: $DAYS)" >&2; exit 2 ;;
esac

if [ ! -d "$VARIANTS_DIR" ]; then
  echo "No variants directory at $VARIANTS_DIR — nothing to decay."
  exit 0
fi

# Portable mtime-in-epoch-seconds (GNU stat, then BSD/macOS stat).
get_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf ''
}

now_epoch=$(date +%s)
cutoff_secs=$(( DAYS * 86400 ))
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

total=0
pruned=0
kept=0

# Iterate only the immediate <round-id> children of variants/ (trailing-slash
# glob matches directories; nullglob yields nothing when the dir is empty).
shopt -s nullglob
for round_dir in "$VARIANTS_DIR"/*/; do
  round_dir="${round_dir%/}"
  [ -d "$round_dir" ] || continue
  total=$((total+1))
  round_id=$(basename "$round_dir")

  mtime_epoch=$(get_mtime "$round_dir")
  if [ -z "$mtime_epoch" ]; then
    echo "  skip: $round_id (cannot determine age — keeping)" >&2
    kept=$((kept+1))
    continue
  fi

  age_secs=$(( now_epoch - mtime_epoch ))
  age_days=$(( age_secs / 86400 ))

  # Keep anything within the retention window (strictly: prune only when older).
  if [ "$age_secs" -le "$cutoff_secs" ]; then
    kept=$((kept+1))
    continue
  fi

  if $DRY_RUN; then
    echo "  would prune: $round_id (age ${age_days}d)"
  else
    # Record the pruned round before removing it — the log is the surviving evidence.
    mkdir -p "$RUNS_DIR"
    printf '{"ts":"%s","round":"%s","age_days":%s,"days_window":%s,"reason":"decay: older than retention window"}\n' \
      "$ts" "$round_id" "$age_days" "$DAYS" >> "$DECAY_LOG"
    rm -rf -- "$round_dir"
    echo "  pruned: $round_id (age ${age_days}d)"
  fi
  pruned=$((pruned+1))
done
shopt -u nullglob

if $DRY_RUN; then
  echo "Dry run: $pruned of $total round(s) would be pruned, $kept kept (window: ${DAYS}d)."
else
  echo "Decay: $pruned of $total round(s) pruned, $kept kept (window: ${DAYS}d)."
  [ "$pruned" -gt 0 ] && echo "Log: $DECAY_LOG"
fi
exit 0
