#!/usr/bin/env bash
# Tests for memory/tools/init.sh — tree creation, idempotency, --force, and the
# ARTEFACTS_DIR override.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

INIT="$KIT_ROOT/memory/tools/init.sh"

# Run init with an isolated artefacts dir.
_init() { ARTEFACTS_DIR="$1" bash "$INIT" "${@:2}" >/dev/null 2>&1; }

test_creates_all_layers() {
  local art; art="$(make_tmp_project)/.akt"
  _init "$art" || fail "init failed"
  assert_file_exists "$art/MEMORY.md"             "L4 root"
  assert_file_exists "$art/SESSION-STATE.md"      "L1 hot state"
  assert_file_exists "$art/memory/SCHEMA.md"      "ontology"
  for f in preferences system projects decisions; do
    assert_file_exists "$art/memory/$f.md" "L3 $f"
  done
  assert_file_exists "$art/memory/$(date +%Y-%m-%d).md" "today's L2 daily"
}

test_skips_existing_without_force() {
  local art; art="$(make_tmp_project)/.akt"
  _init "$art"
  printf '\nUSER EDIT\n' >> "$art/memory/preferences.md"
  _init "$art"   # second run, no --force
  assert_file_contains "$art/memory/preferences.md" "USER EDIT" "existing file untouched"
}

test_force_overwrites_from_template() {
  local art; art="$(make_tmp_project)/.akt"
  _init "$art"
  printf '\nUSER EDIT\n' >> "$art/memory/preferences.md"
  _init "$art" --force
  assert_file_not_contains "$art/memory/preferences.md" "USER EDIT" "--force resets from template"
}

test_artefacts_dir_override_is_honoured() {
  local proj; proj=$(make_tmp_project)
  local art="$proj/.kit-state"
  _init "$art"
  assert_dir_exists "$art/memory" "custom ARTEFACTS_DIR used"
  assert_file_absent "$proj/.akt" "default .akt not created when overridden"
}

run_tests "$@"
