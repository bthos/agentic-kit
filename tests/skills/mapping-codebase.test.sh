#!/usr/bin/env bash
# mapping-codebase (onboarding map) — new-map.sh bootstrap behaviour.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

test_new_map_requires_slug() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  if ( cd "$proj" && bash talaka/skills/mapping-codebase/new-map.sh ) >/dev/null 2>&1; then
    fail "new-map.sh should fail without a slug"
  fi
}

test_new_map_creates_folder() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/mapping-codebase/new-map.sh payments ) >/dev/null

  local dir="$proj/.tlk/maps/$(date +%Y-%m-%d)-payments"
  assert_dir_exists  "$dir"
  assert_file_exists "$dir/map.md"
  assert_file_exists "$dir/open-questions.md"
  assert_file_exists "$dir/handoff-log.md"

  # Placeholders rendered everywhere.
  assert_file_not_contains "$dir/map.md" "{{MAP_ID}}" "map has MAP_ID rendered"
  assert_file_not_contains "$dir/map.md" "{{DATE}}" "map has DATE rendered"
  assert_file_not_contains "$dir/handoff-log.md" "{{MAP_ID}}" "handoff has MAP_ID rendered"
  assert_file_contains "$dir/map.md" "payments" "map carries the slug"
}

test_new_map_is_idempotent() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/mapping-codebase/new-map.sh payments ) >/dev/null
  local dir="$proj/.tlk/maps/$(date +%Y-%m-%d)-payments"
  echo "USER-EDIT" >> "$dir/map.md"

  local out
  out=$( cd "$proj" && bash talaka/skills/mapping-codebase/new-map.sh payments )
  assert_contains "$out" "already exists" "second run refuses to clobber"
  assert_file_contains "$dir/map.md" "USER-EDIT" "re-run preserves user edits"
}

test_new_map_emits_map_path() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  local out
  out=$( cd "$proj" && bash talaka/skills/mapping-codebase/new-map.sh auth )
  assert_contains "$out" "MAP_PATH=.tlk/maps/$(date +%Y-%m-%d)-auth" \
    "prints machine-readable MAP_PATH"
}

run_tests "$@"
