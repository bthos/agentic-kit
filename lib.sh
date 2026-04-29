#!/usr/bin/env bash
# Shared helpers for agentic-kit shell scripts.
# Source from init.sh / update.sh / teardown.sh:  source "$(dirname "$0")/lib.sh"
# shellcheck shell=bash

# ---------------------------------------------------------------------------
# Colors & output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  CYAN='\033[36m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RED='\033[31m'
  RESET='\033[0m'
else
  BOLD='' DIM='' CYAN='' GREEN='' YELLOW='' RED='' RESET=''
fi

info()    { printf "  ${DIM}%s${RESET}\n" "$*"; }
success() { printf "  ${GREEN}+${RESET} %s\n" "$*"; }
skip()    { printf "  ${YELLOW}skip${RESET} %s\n" "$*"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
err()     { printf "  ${RED}error${RESET} %s\n" "$*"; }
header()  { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$*"; }
removed() { printf "  ${RED}-${RESET} %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Kit paths & marker (kit directory = directory containing this file)
# ---------------------------------------------------------------------------
AGENTIC_MARKER='<!-- agentic-kit managed -->'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_DIR=$(basename "$SCRIPT_DIR")
KIT_CFG="$PROJECT_ROOT/.agentic-kit.cfg"
