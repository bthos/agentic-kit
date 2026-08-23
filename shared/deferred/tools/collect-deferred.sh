#!/usr/bin/env bash
# Collect open deferred decisions across all features and mark them as collected.
# Usage:
#   shared/deferred/tools/collect-deferred.sh [--dry-run] [--all]
#
# --dry-run  Print report without marking decisions as collected
# --all      Also show previously collected decisions
# shellcheck shell=bash

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.tlk}"

# Source lib.sh for output helpers only
source "$(cd "$(dirname "$0")/../../lifecycle/tools" && pwd)/lib.sh"

DRY_RUN=false
SHOW_ALL=false

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --all)     SHOW_ALL=true; shift ;;
    -h|--help)
      cat >&2 <<EOF
Usage: $0 [--dry-run] [--all]

Scans .tlk/features/*/deferred.md for open decisions, prints a summary,
then marks each as 'collected' so it won't appear in the next run.

Options:
  --dry-run  Preview without marking collected
  --all      Also show previously collected decisions
EOF
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

FEATURES_DIR="$ARTEFACTS/features"

if [ ! -d "$FEATURES_DIR" ]; then
  info "No features directory at $FEATURES_DIR"
  exit 0
fi

TOTAL=0
FEATURE_COUNT=0
COLLECTED_FILES=()

header "Deferred Decisions Report"
echo ""

for deferred_file in "$FEATURES_DIR"/*/deferred.md; do
  [ -f "$deferred_file" ] || continue

  feature_dir=$(dirname "$deferred_file")
  feature_name=$(basename "$feature_dir")

  if [ "$SHOW_ALL" = true ]; then
    STATUS_PATTERN='open|collected'
  else
    STATUS_PATTERN='open'
  fi

  in_entry=false
  entry_status=""
  entry_lines=""
  entry_header=""
  found_in_feature=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^##\ DD-[0-9]+: ]]; then
      if [ "$in_entry" = true ] && [[ "$entry_status" =~ ^($STATUS_PATTERN)$ ]]; then
        if [ $found_in_feature -eq 0 ]; then
          found_in_feature=1
        fi
        printf "  ${BOLD}[%s]${RESET} %s\n" "$feature_name" "$entry_header"
        printf "%s\n" "$entry_lines"
        echo ""
        TOTAL=$((TOTAL + 1))
      fi
      in_entry=true
      entry_header="$line"
      entry_lines=""
      entry_status=""
    elif [ "$in_entry" = true ]; then
      if [[ "$line" =~ ^\-\ \*\*Status:\*\*\ (.+) ]]; then
        entry_status="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ ^\-\ \*\*Trigger:\*\* ]] || [[ "$line" =~ ^\-\ \*\*Deferred\ by:\*\* ]] || [[ "$line" =~ ^\-\ \*\*Date:\*\* ]]; then
        entry_lines+="    $line"$'\n'
      fi
    fi
  done < "$deferred_file"

  # Process last entry
  if [ "$in_entry" = true ] && [[ "$entry_status" =~ ^($STATUS_PATTERN)$ ]]; then
    if [ $found_in_feature -eq 0 ]; then
      found_in_feature=1
    fi
    printf "  ${BOLD}[%s]${RESET} %s\n" "$feature_name" "$entry_header"
    printf "%s\n" "$entry_lines"
    echo ""
    TOTAL=$((TOTAL + 1))
  fi

  if [ $found_in_feature -gt 0 ]; then
    FEATURE_COUNT=$((FEATURE_COUNT + 1))
    COLLECTED_FILES+=("$deferred_file")
  fi
done

if [ $TOTAL -eq 0 ]; then
  info "No open deferred decisions found."
  exit 0
fi

echo "  Total: $TOTAL open decision(s) across $FEATURE_COUNT feature(s)"

if [ "$DRY_RUN" = true ]; then
  warn "(dry-run: decisions NOT marked as collected)"
else
  for f in "${COLLECTED_FILES[@]}"; do
    sed -i 's/^\(- \*\*Status:\*\*\) open$/\1 collected/' "$f"
  done
  success "Marked as 'collected' — will not appear in next run"
fi
