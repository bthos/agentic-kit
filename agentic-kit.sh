#!/usr/bin/env bash
# agentic-kit.sh — single entry point for all manual kit workflows.
#
# Run from the project root (the directory that contains agentic-kit/).
# Detects the current install stage and only offers actions that make sense:
#
#   stage 0  not installed       → init only
#   stage 1  installed, unconfigured (PROJECT.md still has <placeholder>s)
#                                → init + probe + edit + validate
#   stage 2  configured, idle    → start a feature, status, memory, update,
#                                  distill lessons, version bump, teardown, …
#
# This script is a launcher only — it never edits project files itself, it
# shells out to the kit's own scripts (tools/init.sh / tools/update.sh / tools/teardown.sh and
# helpers under tools/ + autoresearch/tools/).

set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$KIT/.." && pwd)"
ART_NAME="${ARTEFACTS_DIR_NAME:-.artefacts}"
ART="$ROOT/$ART_NAME"
CFG="$ART/.agentic-kit.cfg"
PROJECT_MD="$ART/PROJECT.md"

cd "$ROOT"

# ---------------------------------------------------------------------------
# CLI arg parsing — single positional action lets CI / agents bypass the menu
# ---------------------------------------------------------------------------
ACTION_ARG=""
LIST_JSON=false
SHOW_HELP=false
for arg in "$@"; do
  case "$arg" in
    -h|--help)         SHOW_HELP=true ;;
    -n|--non-interactive) ;;  # accepted for symmetry with siblings; menu auto-detects no-TTY
    --list-json)       LIST_JSON=true ;;
    -*)                printf "unknown flag: %s\n" "$arg" >&2; exit 2 ;;
    *)                 ACTION_ARG="$arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# Look & feel
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m';   DIM=$'\033[2m';    RESET=$'\033[0m'
  CYAN=$'\033[36m';  GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  RED=$'\033[31m';   MAGENTA=$'\033[35m'; BLUE=$'\033[34m'
  GREY=$'\033[90m'
  BG_GREEN=$'\033[42;30m'; BG_YELLOW=$'\033[43;30m'; BG_RED=$'\033[41;37m'
else
  BOLD=''; DIM=''; RESET=''
  CYAN=''; GREEN=''; YELLOW=''; RED=''; MAGENTA=''; BLUE=''; GREY=''
  BG_GREEN=''; BG_YELLOW=''; BG_RED=''
fi

banner() {
  printf '\n'
  printf "  %s╭─────────────────────────────────────────╮%s\n" "$BOLD$CYAN" "$RESET"
  printf "  %s│            ⚙  agentic-kit               │%s\n" "$BOLD$CYAN" "$RESET"
  printf "  %s│      one menu, every workflow           │%s\n" "$BOLD$CYAN" "$RESET"
  printf "  %s╰─────────────────────────────────────────╯%s\n" "$BOLD$CYAN" "$RESET"
}

rule() { printf "  %s────────────────────────────────────────────────────────%s\n" "$DIM" "$RESET"; }

# ---------------------------------------------------------------------------
# Stage detection
# ---------------------------------------------------------------------------
detect_stage() {
  if [ ! -d "$ART" ] || [ ! -f "$CFG" ]; then
    echo 0; return
  fi
  if [ ! -f "$PROJECT_MD" ] || grep -qF ':** `<' "$PROJECT_MD" 2>/dev/null; then
    echo 1; return
  fi
  echo 2
}

stage_badge() {
  case "$1" in
    0) printf "%s  not installed  %s" "$BG_RED"    "$RESET" ;;
    1) printf "%s  needs config   %s" "$BG_YELLOW" "$RESET" ;;
    2) printf "%s  ready          %s" "$BG_GREEN"  "$RESET" ;;
  esac
}

stage_hint() {
  case "$1" in
    0) printf "Run %s1) init%s to install the kit into this project." "$BOLD" "$RESET" ;;
    1) printf "Edit %s%s/PROJECT.md%s, then run %svalidate%s." "$CYAN" "$ART_NAME" "$RESET" "$BOLD" "$RESET" ;;
    2) printf "All systems go. Pick any action below." ;;
  esac
}

print_header() {
  local stage="$1" ide=""
  banner
  printf "  %sproject%s   %s\n" "$DIM" "$RESET" "$ROOT"
  printf "  %skit%s       %s\n" "$DIM" "$RESET" "$KIT"
  if [ -f "$CFG" ]; then
    ide=$(grep '^IDE=' "$CFG" 2>/dev/null | cut -d= -f2- || true)
  fi
  printf "  %sIDE%s       %s\n" "$DIM" "$RESET" "${ide:-${GREY}—${RESET}}"
  printf "  %sstage%s     %b   %s\n" "$DIM" "$RESET" "$(stage_badge "$stage")" "$(stage_hint "$stage")"
  rule
}

# ---------------------------------------------------------------------------
# Action registry (declared once, filtered per stage)
#
# Row format:
#   key|min_stage|category|label|description|cmd[::arg::arg…]
#
# Multi-token commands are stored with a "::" sentinel so we can rebuild the
# argv at run time without eval. A leading "::" marks a built-in handler.
#
# This registry is the single source of truth for action metadata. README.md's
# "Lifecycle scripts" table should match it — when adding/removing/renaming an
# action, also update README and CHANGELOG. `agentic-kit.sh --list-json` emits
# the registry as JSON so doc generators can stay in sync.
# ---------------------------------------------------------------------------
register_actions() {
  ACTIONS=()
  add() { ACTIONS+=("$1|$2|$3|$4|$5|$6"); }

  # ---- setup ----
  add init     0 setup "Install / refresh kit"           "Run init.sh — copy agents, skills, IDE entry-point block, .gitignore block. Safe to re-run; your edits are preserved." \
       "$KIT/tools/init.sh"
  add probe    1 setup "Probe project (--tune)"          "Inspect repo (package.json, pyproject.toml, Cargo.toml, …) and write $ART_NAME/PROJECT_PROFILE.md so agents self-tune." \
       "$KIT/tools/probe-project.sh::--force"
  add edit-pm  1 setup "Edit PROJECT.md"                 "Open $ART_NAME/PROJECT.md in \$EDITOR (fallback: vi). Fill in stack, test/build commands, version files." \
       "::edit-project-md"
  add validate 1 setup "Validate PROJECT.md"             "Fail if PROJECT.md still has <placeholder> values. Run after editing." \
       "$KIT/tools/validate-config.sh"
  add update   2 setup "Update kit"                      "git submodule update --remote agentic-kit, then re-run init.sh with your saved IDE." \
       "$KIT/tools/update.sh"
  add teardown 1 setup "Uninstall (teardown)"            "Strip managed include blocks; remove kit-installed copies whose SHA-256 still matches the manifest. Asks for extra args." \
       "::teardown-prompt"

  # ---- daily ----
  add status   2 daily "Feature pipeline status"         "Show spec / UX / tech-plan / handoff state for every active feature under $ART_NAME/features/." \
       "$KIT/tools/feature-status.sh"
  add memory   2 daily "Search memory"                   "Top-k retrieval across all memory layers (L1..L4). Prompts for a query." \
       "::memory-prompt"

  # ---- maintenance ----
  add bump     2 maint "Bump version (patch)"            "Increment Z in X.Y.Z across every file listed under 'Version files:' in PROJECT.md." \
       "$KIT/tools/bump-version.sh::patch"
  add bump-min 2 maint "Bump version (minor)"            "Increment Y, reset Z. Run before commit when shipping a new feature." \
       "$KIT/tools/bump-version.sh::minor"
  add mem-roll 2 maint "Memory rollover"                 "Empty stale L1 in-flight decisions; compact L2 daily files older than 7 days into a weekly stub." \
       "$KIT/tools/memory-rollover.sh"
  add mem-prom 2 maint "Memory promote (2-strike)"       "Run the L2→L3 promotion state machine; rebuild MEMORY.md root index." \
       "$KIT/tools/memory-promote.sh"
  add distill  2 maint "Distill lessons from archive"    "Read every archived feature's LESSONS.md and append to today's L2 daily memory." \
       "$KIT/tools/distill-lessons.sh"
  add patches  2 maint "Review proposed patches"         "Walk through $ART_NAME/proposed-patches/ interactively; accept or skip each." \
       "$KIT/tools/apply-patches.sh"
}

cat_label() {
  case "$1" in
    setup) printf "%sSetup & lifecycle%s"        "$BOLD$MAGENTA" "$RESET" ;;
    daily) printf "%sDaily work%s"               "$BOLD$BLUE"    "$RESET" ;;
    maint) printf "%sMaintenance & memory%s"     "$BOLD$CYAN"    "$RESET" ;;
  esac
}

# ---------------------------------------------------------------------------
# Render menu
# ---------------------------------------------------------------------------
print_menu() {
  local stage="$1"
  local i=0 row key min cat label desc current=""
  MENU_KEYS=()
  printf '\n'
  for cat in setup daily maint; do
    local printed_header=false
    for row in "${ACTIONS[@]}"; do
      IFS='|' read -r key min rcat label _desc _cmd <<<"$row"
      [ "$rcat" = "$cat" ] || continue
      [ "$min" -le "$stage" ] || continue
      if ! $printed_header; then
        printf "  %b\n" "$(cat_label "$cat")"
        printed_header=true
      fi
      i=$((i + 1))
      MENU_KEYS+=("$key")
      printf "    %s%2d%s  %s%-30s%s  %s%s%s\n" \
        "$BOLD$GREEN" "$i" "$RESET" "$BOLD" "$label" "$RESET" "$DIM" "$key" "$RESET"
    done
    $printed_header && printf '\n'
  done
  rule
  printf "    %sh%s  help — describe each action     %sq%s  quit\n\n" \
    "$BOLD" "$RESET" "$BOLD" "$RESET"
}

print_help() {
  local stage="$1"
  local row key min cat label desc current=""
  printf '\n  %sActions available at this stage%s\n' "$BOLD" "$RESET"
  rule
  for cat in setup daily maint; do
    local printed_header=false
    for row in "${ACTIONS[@]}"; do
      IFS='|' read -r key min rcat label desc _cmd <<<"$row"
      [ "$rcat" = "$cat" ] || continue
      [ "$min" -le "$stage" ] || continue
      if ! $printed_header; then
        printf "\n  %b\n\n" "$(cat_label "$cat")"
        printed_header=true
      fi
      printf "    %s%-12s%s %s\n" "$BOLD" "$key" "$RESET" "$label"
      printf "    %s%s%s\n\n" "$DIM" "$desc" "$RESET"
    done
  done
}

# ---------------------------------------------------------------------------
# Action runners
# ---------------------------------------------------------------------------
run_action() {
  local key="$1" row found="" cmd_field
  for row in "${ACTIONS[@]}"; do
    if [[ "$row" == "$key|"* ]]; then found="$row"; break; fi
  done
  [ -n "$found" ] || { printf "  %s✗%s unknown action: %s\n" "$RED" "$RESET" "$key"; return 1; }
  cmd_field="${found##*|}"

  printf "\n  %s▶ running: %s%s\n" "$CYAN" "$key" "$RESET"
  rule

  case "$cmd_field" in
    ::edit-project-md)
      if [ ! -f "$PROJECT_MD" ]; then
        printf "  %s✗%s %s does not exist yet — run %sinit%s first.\n" \
          "$RED" "$RESET" "$PROJECT_MD" "$BOLD" "$RESET"
        return 1
      fi
      "${EDITOR:-vi}" "$PROJECT_MD"
      ;;
    ::memory-prompt)
      if [ ! -t 0 ]; then
        printf "  %s✗%s memory action requires a TTY (or pass query as: agentic-kit.sh memory \"<query>\")\n" \
          "$RED" "$RESET"
        return 1
      fi
      local q
      read -r -p "  search query: " q
      if [ -z "$q" ]; then
        printf "  %s→%s empty query — nothing to do\n" "$YELLOW" "$RESET"
        return 0
      fi
      "$KIT/tools/memory-search.sh" "$q"
      ;;
    ::teardown-prompt)
      if [ ! -t 0 ]; then
        # No TTY → safe default: dry-run so nothing destructive happens by accident.
        printf "  %s→%s no TTY — running teardown.sh --dry-run\n" "$YELLOW" "$RESET"
        "$KIT/tools/teardown.sh" --dry-run
        return 0
      fi
      printf "  %sExamples:%s --dry-run | --full-clean | --remove-submodule | --yes\n" "$DIM" "$RESET"
      local extra=""
      read -r -p "  extra args (blank for none): " extra
      # Word-split the user input safely into an argv array (no eval, no $extra splicing).
      local -a teardown_args=()
      if [ -n "$extra" ]; then
        # shellcheck disable=SC2206  # we want word-splitting, not glob expansion
        IFS=' ' read -r -a teardown_args <<<"$extra"
      fi
      "$KIT/tools/teardown.sh" "${teardown_args[@]}"
      ;;
    *)
      # split on "::" sentinel without eval
      local rest="$cmd_field" head argv=()
      while [ -n "$rest" ]; do
        head="${rest%%::*}"
        argv+=("$head")
        if [ "$head" = "$rest" ]; then break; fi
        rest="${rest#*::}"
      done
      "${argv[@]}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Top-level help + JSON dump (machine-readable for docs / generators)
# ---------------------------------------------------------------------------
print_top_help() {
  cat <<EOF
agentic-kit.sh — single entry point for all manual kit workflows.

USAGE
  agentic-kit/agentic-kit.sh                     # interactive menu
  agentic-kit/agentic-kit.sh <action>            # run a single action and exit
  agentic-kit/agentic-kit.sh --list-json         # dump action registry as JSON
  agentic-kit/agentic-kit.sh --help              # this help

ACTIONS (filtered by detected stage; see 'h' inside the menu)
EOF
  local row key min cat label desc
  for row in "${ACTIONS[@]}"; do
    IFS='|' read -r key min cat label desc _cmd <<<"$row"
    printf "  %-12s  %s\n" "$key" "$label"
  done
  cat <<'EOF'

STAGES
  0  not installed   → only 'init' is offered
  1  needs config    → init, probe, edit-pm, validate, teardown
  2  ready           → all actions

NOTES
  Single-action mode auto-detects no-TTY and refuses interactive prompts
  (memory search, teardown extra-args) instead of hanging.
EOF
}

print_list_json() {
  printf '['
  local first=true row key min cat label desc
  for row in "${ACTIONS[@]}"; do
    IFS='|' read -r key min cat label desc _cmd <<<"$row"
    if $first; then first=false; else printf ','; fi
    # JSON-escape backslashes and quotes in label/desc
    local esc_label esc_desc
    esc_label=${label//\\/\\\\}; esc_label=${esc_label//\"/\\\"}
    esc_desc=${desc//\\/\\\\};   esc_desc=${esc_desc//\"/\\\"}
    printf '\n  {"key":"%s","min_stage":%s,"category":"%s","label":"%s","description":"%s"}' \
      "$key" "$min" "$cat" "$esc_label" "$esc_desc"
  done
  printf '\n]\n'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
register_actions

if $SHOW_HELP; then print_top_help; exit 0; fi
if $LIST_JSON;  then print_list_json; exit 0; fi

# Single-action mode: skip the menu entirely.
if [ -n "$ACTION_ARG" ]; then
  STAGE=$(detect_stage)
  # Validate the action exists at all and is allowed at the current stage.
  found_row=""
  for row in "${ACTIONS[@]}"; do
    IFS='|' read -r key min _cat _label _desc _cmd <<<"$row"
    if [ "$key" = "$ACTION_ARG" ]; then found_row="$row"; found_min="$min"; break; fi
  done
  if [ -z "$found_row" ]; then
    printf "agentic-kit.sh: unknown action '%s' (try --help)\n" "$ACTION_ARG" >&2
    exit 2
  fi
  if [ "$found_min" -gt "$STAGE" ]; then
    printf "agentic-kit.sh: action '%s' requires stage >= %s (current: %s)\n" \
      "$ACTION_ARG" "$found_min" "$STAGE" >&2
    exit 3
  fi
  run_action "$ACTION_ARG"
  exit $?
fi

# No action arg → interactive menu requires a TTY.
if [ ! -t 0 ] || [ ! -t 1 ]; then
  printf "agentic-kit.sh: no TTY — pass an action name (e.g. 'agentic-kit.sh status') or --help\n" >&2
  exit 2
fi

while true; do
  STAGE=$(detect_stage)
  print_header "$STAGE"
  print_menu "$STAGE"

  printf "  %schoice%s [number / key / h / q]: " "$BOLD" "$RESET"
  read -r choice || exit 0

  case "$choice" in
    ""|q|Q) printf "\n  %sbye.%s\n\n" "$DIM" "$RESET"; exit 0 ;;
    h|H)    print_help "$STAGE"; continue ;;
  esac

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    idx=$((choice - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#MENU_KEYS[@]}" ]; then
      printf "  %s✗%s out of range: %s\n" "$RED" "$RESET" "$choice"
      continue
    fi
    chosen_key="${MENU_KEYS[$idx]}"
  else
    chosen_key="$choice"
  fi

  if run_action "$chosen_key"; then
    rule
    printf "  %s✓ done%s — re-detecting stage…\n" "$GREEN" "$RESET"
  else
    rule
    printf "  %s✗ action failed: %s%s\n" "$RED" "$chosen_key" "$RESET"
  fi
done
