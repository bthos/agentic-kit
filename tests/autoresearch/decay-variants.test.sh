#!/usr/bin/env bash
# Tests for autoresearch/tools/decay-variants.sh — the only sanctioned way to
# prune Навь (variants/) once snapshots age past the retention window.
# Fully deterministic, no LLM.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

DECAY="$KIT_ROOT/autoresearch/tools/decay-variants.sh"

# Set a directory's mtime to N days ago. GNU (touch -d) then BSD/macOS (touch -t).
_age_dir() {  # _age_dir DIR DAYS_AGO
  local dir="$1" days="$2"
  touch -d "$days days ago" "$dir" 2>/dev/null \
    || touch -t "$(date -v-"${days}"d +%Y%m%d%H%M 2>/dev/null)" "$dir" 2>/dev/null
}

# Create variants/<id> with a baseline+proposal snapshot, aged DAYS_AGO days.
# Contents are written first; the dir mtime is aged last so it sticks.
_round() {  # _round ART ID DAYS_AGO
  local art="$1" id="$2" age="$3"
  local d="$art/autoresearch/variants/$id"
  mkdir -p "$d/baseline" "$d/proposal"
  echo "agent prompt" > "$d/baseline/agent.md"
  echo "mutated prompt" > "$d/proposal/agent.md"
  _age_dir "$d" "$age"
}

_run() { ARTEFACTS_DIR="$1" bash "$DECAY" "${@:2}" >/dev/null 2>&1; }

test_prunes_round_older_than_window() {
  local art; art="$(make_tmp_project)/.tlk"
  _round "$art" old_round 120
  _round "$art" fresh_round 1
  _run "$art"
  assert_file_absent "$art/autoresearch/variants/old_round" "round older than 90d pruned"
  assert_dir_exists  "$art/autoresearch/variants/fresh_round"  "recent round kept"
}

test_records_pruned_round_in_decay_log_before_removal() {
  local art; art="$(make_tmp_project)/.tlk"
  _round "$art" old_round 120
  _run "$art"
  local log="$art/autoresearch/runs/decay.jsonl"
  assert_file_exists   "$log" "decay.jsonl written"
  assert_file_contains "$log" '"round":"old_round"' "pruned round id recorded as evidence"
  assert_file_contains "$log" '"days_window":90'    "retention window recorded"
}

test_dry_run_deletes_nothing() {
  local art; art="$(make_tmp_project)/.tlk"
  _round "$art" old_round 120
  _run "$art" --dry-run
  assert_dir_exists  "$art/autoresearch/variants/old_round" "dry-run keeps the snapshot"
  assert_file_absent "$art/autoresearch/runs/decay.jsonl"   "dry-run writes no decay log"
}

test_respects_custom_days_window() {
  local art; art="$(make_tmp_project)/.tlk"
  _round "$art" round_100d 100
  _run "$art" --days 200   # 100d-old round is inside a 200d window → keep
  assert_dir_exists "$art/autoresearch/variants/round_100d" "round within custom window kept"
}

test_missing_variants_dir_is_graceful() {
  local art; art="$(make_tmp_project)/.tlk"
  mkdir -p "$art"
  # No variants/ at all — exit cleanly, not error.
  assert_ok env ARTEFACTS_DIR="$art" bash "$DECAY"
}

test_rejects_non_numeric_days() {
  local art; art="$(make_tmp_project)/.tlk"
  mkdir -p "$art/autoresearch/variants"
  assert_fail env ARTEFACTS_DIR="$art" bash "$DECAY" --days abc
}

run_tests "$@"
