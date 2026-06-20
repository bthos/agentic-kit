#!/usr/bin/env bash
# Tests for memory/tools/rollover.sh — stale SESSION-STATE clearing (mtime > 24h)
# and 7-day L2 daily compaction.
#
# SESSION clearing uses python3; those cases skip when it is absent.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

ROLLOVER="$KIT_ROOT/memory/tools/rollover.sh"
have_python() { command -v python3 >/dev/null 2>&1; }

_fresh_art() {
  local art; art="$(make_tmp_project)/.tlk"
  mkdir -p "$art/memory"
  printf '%s' "$art"
}
_session() {
  printf '# Session State (L1 — Hot)\n\n## Active feature\n_(none)_\n\n## In-flight decisions\n- Considering switching to GraphQL.\n' > "$1"
}
_run() { ARTEFACTS_DIR="$1" bash "$ROLLOVER" "${@:2}"; }

test_clears_stale_session_state() {
  have_python || { skip_test "python3 absent — SESSION clearing is a no-op"; return; }
  local art; art=$(_fresh_art)
  _session "$art/SESSION-STATE.md"
  touch -t 202001010000 "$art/SESSION-STATE.md"   # ancient mtime (>24h), portable
  _run "$art" >/dev/null 2>&1
  assert_file_contains "$art/SESSION-STATE.md" "auto-cleared" "stale in-flight section cleared"
  assert_file_not_contains "$art/SESSION-STATE.md" "Considering switching to GraphQL." "old decision removed"
}

test_keeps_fresh_session_state() {
  local art; art=$(_fresh_art)
  _session "$art/SESSION-STATE.md"   # just-created → recent mtime
  _run "$art" >/dev/null 2>&1
  assert_file_contains "$art/SESSION-STATE.md" "Considering switching to GraphQL." "fresh decisions preserved"
}

test_compacts_old_daily_file() {
  local art; art=$(_fresh_art)
  local old="$art/memory/2020-01-01.md"
  printf '# Daily memory — 2020-01-01 (L2)\n\n- id: mem_aaaa1111\n  text: |\n    Ancient note.\n' > "$old"
  _run "$art" >/dev/null 2>&1
  assert_file_exists "$art/memory/2020-01-01.md.compact" "original preserved as .compact"
  assert_file_contains "$old" "(compacted)" "live file replaced with compacted stub"
}

test_keeps_recent_daily_file() {
  local art; art=$(_fresh_art)
  local recent="$art/memory/$(date +%Y-%m-%d).md"
  printf '# Daily memory — today (L2)\n\n- id: mem_bbbb2222\n  text: |\n    Today note.\n' > "$recent"
  _run "$art" >/dev/null 2>&1
  assert_file_absent "$recent.compact" "recent daily not compacted"
  assert_file_contains "$recent" "Today note." "recent daily untouched"
}

test_dry_run_does_not_compact() {
  local art; art=$(_fresh_art)
  local old="$art/memory/2020-01-01.md"
  printf '# Daily memory — 2020-01-01 (L2)\n\n- id: mem_cccc3333\n  text: |\n    Old note.\n' > "$old"
  local out; out=$(_run "$art" --dry-run 2>&1)
  assert_contains "$out" "would compact" "dry-run announces the compaction"
  assert_file_absent "$old.compact" "dry-run created no .compact file"
}

run_tests "$@"
