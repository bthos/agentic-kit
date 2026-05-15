#!/usr/bin/env bash
# Drives N rounds of (mutate → ratchet) over installed agent/skill files.
#
# Usage:
#   agentic-kit/autoresearch/run.sh --rounds=3
#   agentic-kit/autoresearch/run.sh --init                 # install templates + build eval-set
#   agentic-kit/autoresearch/run.sh --rounds=2 --target .claude/agents/cmok.md
#
# Run from project root.
#
# Environment:
#   ARTEFACTS_DIR  Path to the project artefacts folder (default: .akt)

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$(cd "$KIT_DIR/../templates/autoresearch" && pwd)"
PROJECT_ROOT="$(pwd)"
ARTEFACTS="${ARTEFACTS_DIR:-$PROJECT_ROOT/.akt}"

EVAL_DIR="$ARTEFACTS/autoresearch/eval-set"
RUNS_DIR="$ARTEFACTS/autoresearch/runs"
VARIANTS_DIR="$ARTEFACTS/autoresearch/variants"
PROGRAM="$ARTEFACTS/autoresearch/program.md"
TOOLS_DIR="$ARTEFACTS/autoresearch/tools"

ROUNDS=1
TARGET=""
INIT=false

for arg in "$@"; do
  case "$arg" in
    --rounds=*) ROUNDS="${arg#--rounds=}" ;;
    --target=*) TARGET="${arg#--target=}" ;;
    --target)   shift; TARGET="${1:-}";;
    --init)     INIT=true ;;
    -h|--help)  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

mkdir -p "$EVAL_DIR" "$RUNS_DIR" "$VARIANTS_DIR" "$TOOLS_DIR"

if $INIT; then
  echo "Initialising autoresearch loop…"

  # Install program.md template (never overwrite if project has already edited it)
  if [ ! -f "$PROGRAM" ]; then
    cp "$TEMPLATES_DIR/program.md" "$PROGRAM"
    echo "  Installed: $PROGRAM"
  else
    echo "  Kept existing: $PROGRAM"
  fi

  # Install record-metrics.sh template (same rule — never overwrite)
  METRICS_SCRIPT="$TOOLS_DIR/record-metrics.sh"
  if [ ! -f "$METRICS_SCRIPT" ]; then
    cp "$TEMPLATES_DIR/tools/record-metrics.sh" "$METRICS_SCRIPT"
    chmod +x "$METRICS_SCRIPT"
    echo "  Installed: $METRICS_SCRIPT"
  else
    echo "  Kept existing: $METRICS_SCRIPT"
  fi

  ARTEFACTS_DIR="$ARTEFACTS" "$KIT_DIR/tools/build-eval-set.sh"
  echo "OK. Eval entries:"
  ls -1 "$EVAL_DIR" 2>/dev/null || echo "  (none yet — archive a feature first)"
  exit 0
fi

# Guard: program.md must exist (run --init first)
if [ ! -f "$PROGRAM" ]; then
  echo "autoresearch not initialised — run: agentic-kit/autoresearch/run.sh --init" >&2
  exit 1
fi

# Build any new eval-set entries from archive (idempotent, never edits existing)
ARTEFACTS_DIR="$ARTEFACTS" "$KIT_DIR/tools/build-eval-set.sh" >/dev/null

# Default candidate set: all installed kit agents/skills
candidates=()
if [ -n "$TARGET" ]; then
  candidates=( "$TARGET" )
else
  for d in .claude/agents .cursor/agents; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do candidates+=( "$f" ); done < <(find "$d" -maxdepth 1 -name '*.md' 2>/dev/null)
  done
  for d in .claude/skills .cursor/skills; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do candidates+=( "$f" ); done < <(find "$d" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null)
  done
fi

if [ ${#candidates[@]} -eq 0 ]; then
  echo "No installed agent/skill files found — run agentic-kit/tools/init.sh first." >&2
  exit 1
fi

shopt -s nullglob
eval_pairs=( "$EVAL_DIR"/*.md )
shopt -u nullglob
if [ ${#eval_pairs[@]} -eq 0 ]; then
  echo "Eval-set is empty (no archived features yet). Veles needs evidence to ratchet."
  echo "Archive at least one feature, then re-run."
  exit 0
fi

consecutive_rejects=0
accepted=0
rejected=0

for ((round=1; round <= ROUNDS; round++)); do
  idx=$(( RANDOM % ${#candidates[@]} ))
  target="${candidates[$idx]}"
  echo
  echo "── Round $round/$ROUNDS — target: $target"

  set +e
  round_id=$(ARTEFACTS_DIR="$ARTEFACTS" "$KIT_DIR/tools/mutate-agent.sh" --target "$target" --reason "round $round" 2>&1)
  rc=$?
  set -e
  if [ $rc -ne 0 ] || [ -z "$round_id" ]; then
    echo "  mutate failed (rc=$rc) — skipping"
    consecutive_rejects=$((consecutive_rejects+1))
    [ "$consecutive_rejects" -ge 3 ] && { echo "Three consecutive failures — stopping."; break; }
    continue
  fi

  set +e
  out=$(ARTEFACTS_DIR="$ARTEFACTS" "$KIT_DIR/tools/ratchet.sh" --round-id "$round_id" --target "$target")
  rc=$?
  set -e
  echo "  $out"

  if [[ "$out" =~ ^ACCEPT ]]; then
    accepted=$((accepted+1)); consecutive_rejects=0
  else
    rejected=$((rejected+1)); consecutive_rejects=$((consecutive_rejects+1))
  fi

  if [ "$consecutive_rejects" -ge 3 ]; then
    echo "Three consecutive rejections — stopping (signals diminishing returns)."
    break
  fi
done

echo
echo "Done. Accepted: $accepted. Rejected: $rejected. Logs: $RUNS_DIR/"
