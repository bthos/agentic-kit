#!/usr/bin/env bash
# Drives N rounds of (mutate → ratchet) over installed agent/skill files.
#
# Usage:
#   agentic-kit/autoresearch/run.sh --rounds=3
#   agentic-kit/autoresearch/run.sh --init                 # prepare directories + eval-set
#   agentic-kit/autoresearch/run.sh --rounds=2 --target .claude/agents/cmok.md
#
# Run from project root.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_DIR="$KIT_DIR/eval-set"
RUNS_DIR="$KIT_DIR/runs"
VARIANTS_DIR="$KIT_DIR/variants"

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

mkdir -p "$EVAL_DIR" "$RUNS_DIR" "$VARIANTS_DIR"

if $INIT; then
  echo "Initialising autoresearch loop…"
  "$KIT_DIR/tools/build-eval-set.sh"
  echo "OK. Eval entries:"
  ls -1 "$EVAL_DIR" 2>/dev/null || echo "  (none yet — archive a feature first)"
  exit 0
fi

# Build any new eval-set entries from archive (idempotent, never edits existing)
"$KIT_DIR/tools/build-eval-set.sh" >/dev/null

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
  echo "No installed agent/skill files found — run agentic-kit/init.sh first." >&2
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
  # Pick a candidate pseudo-randomly weighted toward agents (prompts have more leverage)
  idx=$(( RANDOM % ${#candidates[@]} ))
  target="${candidates[$idx]}"
  echo
  echo "── Round $round/$ROUNDS — target: $target"

  set +e
  round_id=$("$KIT_DIR/tools/mutate-agent.sh" --target "$target" --reason "round $round" 2>&1)
  rc=$?
  set -e
  if [ $rc -ne 0 ] || [ -z "$round_id" ]; then
    echo "  mutate failed (rc=$rc) — skipping"
    consecutive_rejects=$((consecutive_rejects+1))
    [ "$consecutive_rejects" -ge 3 ] && { echo "Three consecutive failures — stopping."; break; }
    continue
  fi

  set +e
  out=$("$KIT_DIR/tools/ratchet.sh" --round-id "$round_id" --target "$target")
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
