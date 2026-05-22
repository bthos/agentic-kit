#!/usr/bin/env bash
# agentic-kit statusline — pipeline-aware status bar for Claude Code.
# Shows active agent + pipeline stage (line 1), context/cost/lines (line 2).
# Requires: jq
set -euo pipefail

input=$(cat)

# --- JSON fields ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
AGENT=$(echo "$input" | jq -r '.agent.name // empty')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // "."')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // "."')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# --- Colors ---
C='\033[36m'   # cyan
M='\033[35m'   # magenta
G='\033[32m'   # green
Y='\033[33m'   # yellow
R='\033[31m'   # red
D='\033[2m'    # dim
B='\033[1m'    # bold
Z='\033[0m'    # reset

# --- Line 1: Agent + Pipeline Stage ---
AKT="$PROJECT_DIR/.akt"
STAGE=""
SLUG=""

if [ -d "$AKT" ]; then
  SESSION_STATE="$AKT/SESSION-STATE.md"
  ACTIVE_AGENT="${AGENT}"
  ACTIVE_FEATURE=""

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
  if [ -n "$ACTIVE_FEATURE" ] && [ -d "$ACTIVE_FEATURE" ]; then
    FEAT_PATH="$ACTIVE_FEATURE"
  elif [ -d "$AKT/features" ]; then
    FEAT_PATH=$(ls -1d "$AKT/features/"*/ 2>/dev/null | sort -r | head -1 || true)
  fi

  # Determine pipeline stage from file presence
  if [ -n "$FEAT_PATH" ] && [ -d "$FEAT_PATH" ]; then
    SLUG=$(basename "$FEAT_PATH" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')
    if [ ! -f "$FEAT_PATH/spec.md" ]; then
      STAGE="SPEC"
    elif [ ! -f "$FEAT_PATH/ux-design.md" ]; then
      STAGE="UX"
    elif [ ! -f "$FEAT_PATH/tech-plan.md" ]; then
      STAGE="ARCH"
    else
      STAGE="BUILD/QA"
    fi
  fi

  # Format line 1
  LINE1=""
  if [ -n "$ACTIVE_AGENT" ]; then
    LINE1="${C}@${ACTIVE_AGENT}${Z}"
  else
    LINE1="${D}(idle)${Z}"
  fi
  if [ -n "$SLUG" ]; then
    LINE1="${LINE1} ${D}|${Z} ${M}${SLUG}${Z} ${D}[${STAGE}]${Z}"
  fi
else
  # No .akt/ — simple fallback
  LINE1="${D}[${MODEL}]${Z}"
  [ -n "$AGENT" ] && LINE1="${LINE1} ${C}@${AGENT}${Z}"
fi

# --- Line 2: Context bar + Cost + Lines ---
BAR_WIDTH=15
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

if [ "$PCT" -lt 50 ]; then
  BAR_COLOR="$G"
elif [ "$PCT" -lt 80 ]; then
  BAR_COLOR="$Y"
else
  BAR_COLOR="$R"
fi

BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${BAR_COLOR}${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${D}${PAD// /░}"
BAR="${BAR}${Z}"

COST_FMT=$(printf '$%.2f' "$COST")
LINES_FMT="${G}+${LINES_ADD}${Z}/${R}-${LINES_DEL}${Z}"

LINE2="${BAR} ${PCT}% ${D}|${Z} ${COST_FMT} ${D}|${Z} ${LINES_FMT}"

# --- Output ---
echo -e "$LINE1"
echo -e "$LINE2"
