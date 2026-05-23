#!/usr/bin/env bash
# agentic-kit statusline — pipeline-aware status bar for Claude Code.
# Line 1 (always): agent | feature [STAGE] | context bar | cost | lines
# Line 2 (alerts): only rendered when something needs attention
# Requires: jq
set -euo pipefail

input=$(cat)

# --- JSON fields ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
AGENT=$(echo "$input" | jq -r '.agent.name // empty')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // "."')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# --- Colors ---
C='\033[36m'; M='\033[35m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'
D='\033[2m'; B='\033[1m'; Z='\033[0m'

# --- Pipeline state ---
AKT="$PROJECT_DIR/.akt"
ACTIVE_AGENT="${AGENT}"
SLUG=""
STAGE=""
FEAT_COUNT=0

if [ -d "$AKT" ]; then
  SESSION_STATE="$AKT/SESSION-STATE.md"

  if [ -f "$SESSION_STATE" ]; then
    sa=$(sed -n '/^## Active agent/{n;p;}' "$SESSION_STATE" 2>/dev/null || true)
    if [ -n "$sa" ] && [[ ! "$sa" =~ ^\(none ]]; then
      [ -z "$ACTIVE_AGENT" ] && ACTIVE_AGENT="$sa"
    fi
    af=$(sed -n '/^## Active feature/{n;p;}' "$SESSION_STATE" 2>/dev/null || true)
    if [ -n "$af" ] && [[ ! "$af" =~ ^\(none ]]; then
      ACTIVE_FEATURE="$af"
    fi
  fi

  # Find active feature folder
  FEAT_PATH=""
  if [ -n "${ACTIVE_FEATURE:-}" ] && [ -d "$ACTIVE_FEATURE" ]; then
    FEAT_PATH="$ACTIVE_FEATURE"
  elif [ -d "$AKT/features" ]; then
    FEAT_PATH=$(ls -1d "$AKT/features/"*/ 2>/dev/null | sort -r | head -1 || true)
  fi

  # Count active features
  if [ -d "$AKT/features" ]; then
    FEAT_COUNT=$(ls -1d "$AKT/features/"*/ 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Determine pipeline stage from file presence
  if [ -n "$FEAT_PATH" ] && [ -d "$FEAT_PATH" ]; then
    SLUG=$(basename "$FEAT_PATH" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')
    if [ ! -f "$FEAT_PATH/spec.md" ]; then STAGE="SPEC"
    elif [ ! -f "$FEAT_PATH/ux-design.md" ]; then STAGE="UX"
    elif [ ! -f "$FEAT_PATH/tech-plan.md" ]; then STAGE="ARCH"
    else STAGE="BUILD/QA"
    fi
  fi
fi

# === LINE 1: Compact always-visible bar ===
L1=""

# Agent
if [ -n "$ACTIVE_AGENT" ]; then
  L1="${C}@${ACTIVE_AGENT}${Z}"
else
  L1="${D}[${MODEL}]${Z}"
fi

# Feature + stage
if [ -n "$SLUG" ]; then
  L1="${L1} ${D}|${Z} ${M}${SLUG}${Z} ${D}[${STAGE}]${Z}"
fi

# Context bar (8-wide)
BAR_WIDTH=8
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
if [ "$PCT" -lt 50 ]; then BAR_COLOR="$G"
elif [ "$PCT" -lt 80 ]; then BAR_COLOR="$Y"
else BAR_COLOR="$R"; fi
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${BAR_COLOR}${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${D}${PAD// /░}"
BAR="${BAR}${Z}"

# Cost + lines
COST_FMT=$(printf '$%.2f' "$COST")
LINES_FMT="${G}+${LINES_ADD}${Z}/${R}-${LINES_DEL}${Z}"

L1="${L1} ${D}|${Z} ${BAR} ${PCT}% ${D}|${Z} ${COST_FMT} ${D}|${Z} ${LINES_FMT}"

echo -e "$L1"

# === LINE 2: Conditional alerts (only if something fires) ===
[ ! -d "$AKT" ] && exit 0

ALERTS=()

# --- Alert: Memory stale (SESSION-STATE.md > 24h) ---
if [ -f "$AKT/SESSION-STATE.md" ]; then
  if command -v stat &>/dev/null; then
    case "$(uname -s)" in
      Darwin*) MTIME=$(stat -f %m "$AKT/SESSION-STATE.md" 2>/dev/null || echo 0) ;;
      *)       MTIME=$(stat -c %Y "$AKT/SESSION-STATE.md" 2>/dev/null || echo 0) ;;
    esac
    NOW=$(date +%s)
    AGE_H=$(( (NOW - MTIME) / 3600 ))
    if [ "$AGE_H" -ge 24 ]; then
      AGE_D=$((AGE_H / 24))
      ALERTS+=("${Y}mem:stale ${AGE_D}d${Z}")
    fi
  fi
fi

# --- Alert: Feature stuck (handoff-log.md last entry > 48h) ---
if [ -n "$FEAT_PATH" ] && [ -d "$FEAT_PATH" ]; then
  HANDOFF="$FEAT_PATH/handoff-log.md"
  if [ -f "$HANDOFF" ]; then
    case "$(uname -s)" in
      Darwin*) HO_MTIME=$(stat -f %m "$HANDOFF" 2>/dev/null || echo 0) ;;
      *)       HO_MTIME=$(stat -c %Y "$HANDOFF" 2>/dev/null || echo 0) ;;
    esac
    HO_AGE_H=$(( ($(date +%s) - HO_MTIME) / 3600 ))
    if [ "$HO_AGE_H" -ge 48 ]; then
      HO_AGE_D=$((HO_AGE_H / 24))
      ALERTS+=("${R}${SLUG} STUCK ${HO_AGE_D}d${Z}")
    fi
  fi
fi

# --- Alert: Yaga investigation active ---
if [ -d "$AKT/debug" ]; then
  ACTIVE_INV=$(ls -1d "$AKT/debug/"*/ 2>/dev/null | sort -r | head -1 || true)
  if [ -n "$ACTIVE_INV" ] && [ -d "$ACTIVE_INV" ]; then
    # Determine phase from file state
    HYPO="$ACTIVE_INV/hypothesis.md"
    INST_LOG="$ACTIVE_INV/instrumentation-log.md"
    FINDINGS="$ACTIVE_INV/findings.md"

    YAGA_PHASE="hypothesize"
    if [ -f "$HYPO" ] && [ "$(wc -l < "$HYPO" 2>/dev/null)" -gt 5 ]; then
      YAGA_PHASE="instrument"
      if [ -f "$INST_LOG" ] && [ "$(wc -l < "$INST_LOG" 2>/dev/null)" -gt 3 ]; then
        YAGA_PHASE="observe"
      fi
      if [ -f "$FINDINGS" ] && [ "$(wc -l < "$FINDINGS" 2>/dev/null)" -gt 3 ]; then
        YAGA_PHASE="strip"
      fi
    fi
    ALERTS+=("${C}yaga:${YAGA_PHASE}${Z}")
  fi
fi

# --- Alert: Autoresearch ratchet status ---
RATCHET_LOG="$AKT/autoresearch/runs/ratchet.jsonl"
REJECTED_LOG="$AKT/autoresearch/runs/rejected.jsonl"
if [ -f "$RATCHET_LOG" ]; then
  ACCEPTED=$(wc -l < "$RATCHET_LOG" 2>/dev/null | tr -d ' ')
  REJECTED=0
  [ -f "$REJECTED_LOG" ] && REJECTED=$(wc -l < "$REJECTED_LOG" 2>/dev/null | tr -d ' ')
  GEN=$((ACCEPTED + REJECTED))
  # Get latest composite score
  SCORE=$(tail -1 "$RATCHET_LOG" 2>/dev/null | jq -r '.proposal_composite // empty' 2>/dev/null || true)
  if [ -n "$SCORE" ]; then
    SCORE_FMT=$(printf '%.2f' "$SCORE")
    ALERTS+=("${G}ratchet:gen${GEN} ↑${SCORE_FMT}${Z}")
  fi
fi

# --- Alert: Multiple active features ---
if [ "$FEAT_COUNT" -gt 1 ]; then
  ALERTS+=("${D}${FEAT_COUNT} feats${Z}")
fi

# Output line 2 only if alerts exist
if [ ${#ALERTS[@]} -gt 0 ]; then
  LINE2=""
  for i in "${!ALERTS[@]}"; do
    [ "$i" -gt 0 ] && LINE2="${LINE2} ${D}|${Z} "
    LINE2="${LINE2}${ALERTS[$i]}"
  done
  echo -e "${Y}⚠${Z} ${LINE2}"
fi
