#!/usr/bin/env bash
# adapting-patterns (external pattern -> project fit) — new-adaptation.sh bootstrap behaviour.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

test_new_adaptation_requires_slug() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  if ( cd "$proj" && bash talaka/skills/adapting-patterns/new-adaptation.sh ) >/dev/null 2>&1; then
    fail "new-adaptation.sh should fail without a slug"
  fi
}

test_new_adaptation_creates_feature_folder() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/adapting-patterns/new-adaptation.sh llm-wiki ) >/dev/null

  local dir="$proj/.tlk/features/$(date +%Y-%m-%d)-adapt-llm-wiki"
  assert_dir_exists  "$dir"
  assert_file_exists "$dir/research-brief.md"
  assert_file_exists "$dir/adaptation.md"
  assert_file_exists "$dir/handoff-log.md"

  # Placeholders rendered everywhere.
  assert_file_not_contains "$dir/research-brief.md" "{{ADAPT_ID}}" "brief has ADAPT_ID rendered"
  assert_file_not_contains "$dir/adaptation.md" "{{SLUG}}" "adaptation has SLUG rendered"
  assert_file_contains "$dir/adaptation.md" "llm-wiki" "adaptation carries the slug"
  # The self-containment guardrail (no hard plugin dependency) is carried into the artifact.
  assert_file_contains "$dir/adaptation.md" "Self-containment" "adaptation carries the self-containment contract"
}

test_new_adaptation_is_idempotent() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/adapting-patterns/new-adaptation.sh llm-wiki ) >/dev/null
  local dir="$proj/.tlk/features/$(date +%Y-%m-%d)-adapt-llm-wiki"
  echo "USER-EDIT" >> "$dir/adaptation.md"

  local out
  out=$( cd "$proj" && bash talaka/skills/adapting-patterns/new-adaptation.sh llm-wiki )
  assert_contains "$out" "already exists" "second run refuses to clobber"
  assert_file_contains "$dir/adaptation.md" "USER-EDIT" "re-run preserves user edits"
}

test_new_adaptation_emits_feature_path() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  local out
  out=$( cd "$proj" && bash talaka/skills/adapting-patterns/new-adaptation.sh printing-press )
  assert_contains "$out" "FEATURE_PATH=.tlk/features/$(date +%Y-%m-%d)-adapt-printing-press" \
    "prints machine-readable FEATURE_PATH"
}

run_tests "$@"
