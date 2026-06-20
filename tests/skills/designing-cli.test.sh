#!/usr/bin/env bash
# designing-cli (CLI factory) — new-cli.sh bootstrap behaviour.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

test_new_cli_requires_slug() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  if ( cd "$proj" && bash talaka/skills/designing-cli/new-cli.sh ) >/dev/null 2>&1; then
    fail "new-cli.sh should fail without a slug"
  fi
}

test_new_cli_creates_feature_folder() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/designing-cli/new-cli.sh linear ) >/dev/null

  local dir="$proj/.tlk/features/$(date +%Y-%m-%d)-cli-linear"
  assert_dir_exists  "$dir"
  assert_file_exists "$dir/research-brief.md"
  assert_file_exists "$dir/design.md"
  assert_file_exists "$dir/scorecard.md"
  assert_file_exists "$dir/handoff-log.md"

  # {{SLUG}} placeholder rendered everywhere
  assert_file_not_contains "$dir/research-brief.md" "{{SLUG}}" "research-brief has SLUG rendered"
  assert_file_not_contains "$dir/design.md" "{{SLUG}}" "design has SLUG rendered"
  assert_file_not_contains "$dir/scorecard.md" "{{SLUG}}" "scorecard has SLUG rendered"
  assert_file_contains "$dir/design.md" "linear" "design carries the slug"

  # The QA contract downstream agents gate on is present.
  assert_file_contains "$dir/scorecard.md" "85" "scorecard names the >=85 gate"
  assert_file_contains "$dir/design.md" "dry-run" "design carries the agent-native contract"
}

test_new_cli_is_idempotent() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/designing-cli/new-cli.sh linear ) >/dev/null
  local dir="$proj/.tlk/features/$(date +%Y-%m-%d)-cli-linear"
  echo "USER-EDIT" >> "$dir/design.md"

  local out
  out=$( cd "$proj" && bash talaka/skills/designing-cli/new-cli.sh linear )
  assert_contains "$out" "already exists" "second run refuses to clobber"
  assert_file_contains "$dir/design.md" "USER-EDIT" "re-run preserves user edits"
}

test_new_cli_emits_feature_path() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  local out
  out=$( cd "$proj" && bash talaka/skills/designing-cli/new-cli.sh espn )
  assert_contains "$out" "FEATURE_PATH=.tlk/features/$(date +%Y-%m-%d)-cli-espn" \
    "prints machine-readable FEATURE_PATH"
}

run_tests "$@"
