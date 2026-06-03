#!/usr/bin/env bash
# Unit tests for the SHA-gated teardown helpers in tools/lib.sh — the logic
# that decides whether teardown.sh is allowed to delete a path. A regression
# here either deletes user-modified files or strands kit files, so these are
# the highest-stakes assertions in the suite.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
source "$KIT_ROOT/tools/lib.sh"

setup() {
  PROJECT_ROOT=$(make_tmp_project)
  KIT_FILES_MANIFEST="$PROJECT_ROOT/.akt/.agentic-kit.files"
  mkdir -p "$PROJECT_ROOT/.akt"
  DRY_RUN=false
  manifest_abort
}

test_file_removed_when_hash_matches() {
  local rel=".claude/agents/cmok.md" abs="$PROJECT_ROOT/.claude/agents/cmok.md"
  mkdir -p "$(dirname "$abs")"; printf 'agent body\n' > "$abs"
  manifest_set_hash "$rel" "$(kit_sha256_file "$abs")"
  kit_managed_file_remove "$rel" >/dev/null
  assert_file_absent "$abs" "matching-hash file removed"
  assert_eq "" "$(manifest_get_hash "$rel")" "manifest entry dropped"
}

test_file_kept_when_hash_mismatches() {
  local rel=".claude/agents/cmok.md" abs="$PROJECT_ROOT/.claude/agents/cmok.md"
  mkdir -p "$(dirname "$abs")"; printf 'agent body\n' > "$abs"
  manifest_set_hash "$rel" "0000000000000000deadbeef"   # stale hash → "modified locally"
  kit_managed_file_remove "$rel" >/dev/null || true
  assert_file_exists "$abs" "locally-modified file is preserved"
}

test_file_kept_when_no_manifest_and_no_marker() {
  local rel="random.md" abs="$PROJECT_ROOT/random.md"
  printf 'not a kit file\n' > "$abs"
  kit_managed_file_remove "$rel" >/dev/null || true
  assert_file_exists "$abs" "unknown file left alone"
}

test_file_removed_via_legacy_marker_without_manifest() {
  local rel="legacy.md" abs="$PROJECT_ROOT/legacy.md"
  printf 'header\n%s\nbody\n' "$AGENTIC_MARKER" > "$abs"
  kit_managed_file_remove "$rel" >/dev/null
  assert_file_absent "$abs" "legacy-marker file removed when no manifest entry"
}

test_dry_run_does_not_delete() {
  local rel=".claude/agents/cmok.md" abs="$PROJECT_ROOT/.claude/agents/cmok.md"
  mkdir -p "$(dirname "$abs")"; printf 'agent body\n' > "$abs"
  manifest_set_hash "$rel" "$(kit_sha256_file "$abs")"
  DRY_RUN=true
  kit_managed_file_remove "$rel" >/dev/null
  assert_file_exists "$abs" "dry-run leaves the file in place"
}

test_tree_removed_when_tree_hash_matches() {
  local rel=".claude/skills/vadavik"; local abs="$PROJECT_ROOT/$rel"
  mkdir -p "$abs"
  printf 'a\n' > "$abs/SKILL.md"; printf 'b\n' > "$abs/helper.sh"
  manifest_set_hash "$rel" "$(kit_sha256_tree "$abs")"
  kit_managed_tree_remove "$rel" "/nonexistent-kit-src" >/dev/null
  assert_file_absent "$abs" "matching-hash tree removed"
}

test_tree_kept_when_modified() {
  local rel=".claude/skills/vadavik"; local abs="$PROJECT_ROOT/$rel"
  mkdir -p "$abs"; printf 'a\n' > "$abs/SKILL.md"
  manifest_set_hash "$rel" "$(kit_sha256_tree "$abs")"
  printf 'local edit\n' >> "$abs/SKILL.md"   # user changed it after install
  kit_managed_tree_remove "$rel" "/nonexistent-kit-src" >/dev/null || true
  assert_dir_exists "$abs" "modified tree preserved"
}

test_include_block_stub_whole_file_removed() {
  local rel="CLAUDE.md" abs="$PROJECT_ROOT/CLAUDE.md"
  agentic_block_write_stub "$abs" ".akt/PIPELINE.md"
  manifest_set_hash "$rel" "stub:$(kit_sha256_file "$abs")"
  kit_include_block_remove "$rel" >/dev/null
  assert_file_absent "$abs" "kit-created stub removed whole"
}

test_include_block_only_stripped_when_user_content_present() {
  local rel="CLAUDE.md" abs="$PROJECT_ROOT/CLAUDE.md"
  printf '# Mine\n\nKeep this.\n' > "$abs"
  agentic_block_append "$abs" ".akt/PIPELINE.md"
  # Not a stub — record block hash so the function strips rather than deletes.
  manifest_set_hash "$rel" "block:$(kit_sha256_file "$abs")"
  kit_include_block_remove "$rel" >/dev/null
  assert_file_exists "$abs" "file with user content kept"
  assert_file_contains "$abs" "Keep this."
  assert_file_not_contains "$abs" "$AGENTIC_BLOCK_BEGIN" "managed block stripped"
}

run_tests "$@"
