#!/usr/bin/env bash
# Tests for memory/tools/session.sh — the L1 SESSION-STATE writer seam.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

SESSION="$KIT_ROOT/memory/tools/session.sh"
_art() { printf '%s' "$(make_tmp_project)/.tlk"; }
_s() { ARTEFACTS_DIR="$1" bash "$SESSION" "${@:2}"; }
_file() { printf '%s/SESSION-STATE.md' "$1"; }

test_creates_file_on_first_write() {
  local art; art=$(_art)
  _s "$art" feature "2026-06-03-login" >/dev/null 2>&1
  assert_file_exists "$(_file "$art")" "SESSION-STATE.md created on demand"
}

test_sets_active_feature() {
  local art; art=$(_art)
  _s "$art" feature "2026-06-03-login" >/dev/null 2>&1
  local f; f=$(_file "$art")
  assert_file_contains "$f" "2026-06-03-login"
  # Value sits directly under the header.
  local line; line=$(awk '/^## Active feature/{getline; print; exit}' "$f")
  assert_eq "2026-06-03-login" "$line" "feature value placed under its header"
}

test_sets_active_agent() {
  local art; art=$(_art)
  _s "$art" agent "eliciting-requirements" >/dev/null 2>&1
  local line; line=$(awk '/^## Active agent/{getline; print; exit}' "$(_file "$art")")
  assert_eq "eliciting-requirements" "$line"
}

test_decisions_accumulate() {
  local art; art=$(_art)
  _s "$art" decision "First decision." >/dev/null 2>&1
  _s "$art" decision "Second decision." >/dev/null 2>&1
  local f; f=$(_file "$art")
  assert_file_contains "$f" "- First decision."
  assert_file_contains "$f" "- Second decision."
  # Placeholder italics gone once a real bullet exists.
  local n; n=$(awk '/^## In-flight decisions/{g=1;next} g&&/^## /{g=0} g&&/^- /{c++} END{print c+0}' "$f")
  assert_eq "2" "$n" "both decision bullets present"
}

test_clear_decisions_resets_section() {
  local art; art=$(_art)
  _s "$art" decision "Will be cleared." >/dev/null 2>&1
  _s "$art" clear-decisions >/dev/null 2>&1
  assert_file_not_contains "$(_file "$art")" "Will be cleared." "decisions reset"
}

test_section_edit_does_not_bleed_into_next() {
  local art; art=$(_art)
  _s "$art" feature "feat-x" >/dev/null 2>&1
  _s "$art" agent "cmok" >/dev/null 2>&1
  # Setting the feature must not clobber the agent value or the decisions header.
  local f; f=$(_file "$art")
  assert_file_contains "$f" "## Active agent"
  assert_file_contains "$f" "cmok"
  assert_file_contains "$f" "## In-flight decisions"
}

test_unknown_command_errors() {
  local art; art=$(_art)
  _s "$art" frobnicate "x" >/dev/null 2>&1 && fail "unknown command should exit non-zero" || true
}

run_tests "$@"
