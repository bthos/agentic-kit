#!/usr/bin/env bash
# End-to-end tests for merge-on-update: init.sh snapshots a merge base under
# .tlk/.base/ and a later init (an "update") reconciles local edits with the
# fresh kit source via 3-way merge instead of skipping or clobbering. The
# per-file/tree merge algorithm itself is unit-tested in merge_helpers.test.sh;
# these assert the install-helpers glue. The kit copy is trimmed to one agent +
# one skill because a full install is slow on Windows/git-bash filesystems.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

AGENT_REL=".claude/agents/cmok.md"
SKILL_REL=".claude/skills/requirements-eliciting/SKILL.md"

_project() {
  local proj; proj=$(make_tmp_project); install_kit_into "$proj"
  # Keep only one agent + one skill so each init is a few files, not ~19 trees.
  find "$proj/talaka/agents" -maxdepth 1 -name '*.md' ! -name 'cmok.md' -delete 2>/dev/null || true
  find "$proj/talaka/skills" -mindepth 1 -maxdepth 1 -type d ! -name 'requirements-eliciting' -exec rm -rf {} + 2>/dev/null || true
  printf '%s' "$proj"
}
_init() { ( cd "$1" && shift && bash talaka/shared/lifecycle/tools/init.sh "$@" </dev/null ) >/dev/null 2>&1; }

_insert_top() { local f="$1" text="$2" t; t=$(mktemp); { head -n1 "$f"; printf '%s\n' "$text"; tail -n +2 "$f"; } > "$t"; mv "$t" "$f"; }
_append()     { printf '%s\n' "$2" >> "$1"; }

# ---------------------------------------------------------------------------

test_fresh_install_seeds_base() {
  local proj; proj=$(_project)
  _init "$proj" --non-interactive || fail "init failed"
  assert_file_exists "$proj/.tlk/.base/$AGENT_REL" "agent merge base snapshotted"
  assert_file_exists "$proj/.tlk/.base/$SKILL_REL" "skill merge base snapshotted"
  assert_ok cmp -s "$proj/.tlk/.base/$AGENT_REL" "$proj/$AGENT_REL"
}

test_nonoverlapping_edits_merge_clean() {
  local proj; proj=$(_project)
  _init "$proj" --non-interactive || fail "init failed"

  # Local edits at end; simulated new-kit edits near the top → no overlap.
  # Exercises both install_kit_copy_file (agent) and install_kit_copy_tree (skill).
  _append     "$proj/$AGENT_REL"                                   "LOCAL_AGENT_END"
  _insert_top "$proj/talaka/agents/cmok.md"                        "KIT_AGENT_TOP"
  _append     "$proj/$SKILL_REL"                                   "LOCAL_SKILL_END"
  _insert_top "$proj/talaka/skills/requirements-eliciting/SKILL.md" "KIT_SKILL_TOP"

  _init "$proj" --non-interactive || fail "re-init (update) failed"

  assert_file_contains     "$proj/$AGENT_REL" "LOCAL_AGENT_END" "agent local edit preserved"
  assert_file_contains     "$proj/$AGENT_REL" "KIT_AGENT_TOP"   "agent kit update applied"
  assert_file_not_contains "$proj/$AGENT_REL" "<<<<<<<"         "agent clean merge, no markers"
  assert_file_contains     "$proj/$SKILL_REL" "LOCAL_SKILL_END" "skill local edit preserved"
  assert_file_contains     "$proj/$SKILL_REL" "KIT_SKILL_TOP"   "skill kit update applied"
  assert_file_not_contains "$proj/$SKILL_REL" "<<<<<<<"         "skill clean merge, no markers"
  # Base advanced to the new kit version.
  assert_file_contains "$proj/.tlk/.base/$AGENT_REL" "KIT_AGENT_TOP" "agent base advanced"
}

test_overlapping_conflict_skip_keeps_local() {
  local proj; proj=$(_project)
  _init "$proj" --non-interactive || fail "init failed"

  # Both sides append a different line at EOF → overlapping insert → conflict.
  _append "$proj/$AGENT_REL"            "OURS_TAIL"
  _append "$proj/talaka/agents/cmok.md" "THEIRS_TAIL"

  _init "$proj" --non-interactive   # skip/non-interactive
  assert_file_contains     "$proj/$AGENT_REL" "OURS_TAIL"   "local kept on skip-conflict"
  assert_file_not_contains "$proj/$AGENT_REL" "THEIRS_TAIL" "kit not merged on skip-conflict"
  assert_file_exists       "$proj/.tlk/.conflicts/$AGENT_REL.newkit" "incoming kit saved to sidecar"
  assert_file_not_contains "$proj/.tlk/.base/$AGENT_REL" "THEIRS_TAIL" "base NOT advanced on unresolved conflict"
}

test_force_takes_kit_on_conflict() {
  local proj; proj=$(_project)
  _init "$proj" --non-interactive || fail "init failed"
  _append "$proj/$AGENT_REL"            "OURS_TAIL"
  _append "$proj/talaka/agents/cmok.md" "THEIRS_TAIL"

  _init "$proj" --force --non-interactive
  assert_file_contains     "$proj/$AGENT_REL" "THEIRS_TAIL" "--force takes kit version"
  assert_file_not_contains "$proj/$AGENT_REL" "OURS_TAIL"   "--force discards local"
}

run_tests "$@"
