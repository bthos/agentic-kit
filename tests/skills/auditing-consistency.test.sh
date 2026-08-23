#!/usr/bin/env bash
# consistency-auditing (cross-corpus drift audit) — new-audit.sh bootstrap behaviour.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

test_new_audit_requires_slug() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  if ( cd "$proj" && bash talaka/skills/consistency-auditing/new-audit.sh ) >/dev/null 2>&1; then
    fail "new-audit.sh should fail without a slug"
  fi
}

test_new_audit_creates_folder() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/consistency-auditing/new-audit.sh model-naming ) >/dev/null

  local dir="$proj/.tlk/audits/$(date +%Y-%m-%d)-model-naming"
  assert_dir_exists  "$dir"
  assert_file_exists "$dir/audit.md"
  assert_file_exists "$dir/handoff-log.md"

  # Placeholders rendered everywhere.
  assert_file_not_contains "$dir/audit.md" "{{AUDIT_ID}}" "audit has AUDIT_ID rendered"
  assert_file_not_contains "$dir/audit.md" "{{DATE}}" "audit has DATE rendered"
  assert_file_contains "$dir/audit.md" "model-naming" "audit carries the slug"
  # The fix contract downstream agents act on is present.
  assert_file_contains "$dir/audit.md" "Recommended fix" "audit names the fix contract"
}

test_new_audit_is_idempotent() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  ( cd "$proj" && bash talaka/skills/consistency-auditing/new-audit.sh paths ) >/dev/null
  local dir="$proj/.tlk/audits/$(date +%Y-%m-%d)-paths"
  echo "USER-EDIT" >> "$dir/audit.md"

  local out
  out=$( cd "$proj" && bash talaka/skills/consistency-auditing/new-audit.sh paths )
  assert_contains "$out" "already exists" "second run refuses to clobber"
  assert_file_contains "$dir/audit.md" "USER-EDIT" "re-run preserves user edits"
}

test_new_audit_emits_audit_path() {
  local proj; proj=$(make_tmp_project)
  install_kit_into "$proj"
  local out
  out=$( cd "$proj" && bash talaka/skills/consistency-auditing/new-audit.sh post-rename )
  assert_contains "$out" "AUDIT_PATH=.tlk/audits/$(date +%Y-%m-%d)-post-rename" \
    "prints machine-readable AUDIT_PATH"
}

run_tests "$@"
