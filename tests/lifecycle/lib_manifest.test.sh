#!/usr/bin/env bash
# Unit tests for the install-manifest helpers in tools/lib.sh
# (.akt/.agentic-kit.files: relpath<TAB>hash), both direct and transactional.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
source "$KIT_ROOT/tools/lib.sh"

# Point the manifest at a fresh temp file before each test.
setup() {
  _MF_TMP=$(mktemp -d "${TMPDIR:-/tmp}/akt-mf.XXXXXX")
  KIT_FILES_MANIFEST="$_MF_TMP/.agentic-kit.files"
  # Reset transactional state in case a prior test left it loaded.
  manifest_abort
}
teardown() { rm -rf "$_MF_TMP" 2>/dev/null || true; }

test_direct_set_get_remove() {
  manifest_set_hash ".claude/agents/cmok.md" "abc123"
  assert_eq "abc123" "$(manifest_get_hash '.claude/agents/cmok.md')" "get returns set hash"
  manifest_remove_entry ".claude/agents/cmok.md"
  assert_eq "" "$(manifest_get_hash '.claude/agents/cmok.md')" "get empty after remove"
}

test_direct_set_replaces_not_duplicates() {
  manifest_set_hash "a.md" "hash1"
  manifest_set_hash "a.md" "hash2"
  assert_eq "hash2" "$(manifest_get_hash 'a.md')" "second set wins"
  # Only one physical line for the key.
  local n; n=$(grep -c $'^a.md\t' "$KIT_FILES_MANIFEST")
  assert_eq "1" "$n" "no duplicate manifest lines"
}

test_manifest_line_is_tab_separated() {
  manifest_set_hash "x/y.md" "deadbeef"
  assert_file_contains "$KIT_FILES_MANIFEST" $'x/y.md\tdeadbeef'
}

test_transactional_commit_writes_sorted_atomically() {
  manifest_begin
  manifest_set_hash "zeta.md" "h3"
  manifest_set_hash "alpha.md" "h1"
  manifest_set_hash "mid.md" "h2"
  # Buffer is queryable mid-transaction without touching disk.
  assert_eq "h1" "$(manifest_get_hash 'alpha.md')" "buffered get works"
  # Nothing written to disk yet — the on-disk file has no buffered keys.
  assert_eq "0" "$(grep -c 'alpha.md' "$KIT_FILES_MANIFEST" 2>/dev/null; true)" "buffered add not on disk pre-commit"
  manifest_commit
  # After commit: all three present and sorted (alpha < mid < zeta).
  local order; order=$(cut -f1 "$KIT_FILES_MANIFEST" | tr '\n' ' ')
  assert_eq "alpha.md mid.md zeta.md " "$order" "committed entries are LC_ALL=C sorted"
}

test_transactional_abort_discards() {
  manifest_set_hash "pre.md" "kept"      # direct write before txn
  manifest_begin
  manifest_set_hash "tmp.md" "discarded"
  manifest_remove_entry "pre.md"
  manifest_abort
  # pre.md survives, tmp.md never landed.
  assert_eq "kept" "$(manifest_get_hash 'pre.md')" "abort keeps pre-txn entry"
  assert_eq "" "$(manifest_get_hash 'tmp.md')" "abort discards buffered add"
}

test_transactional_remove_in_buffer() {
  manifest_set_hash "gone.md" "x"
  manifest_begin
  manifest_remove_entry "gone.md"
  assert_eq "" "$(manifest_get_hash 'gone.md')" "buffered remove hides entry"
  manifest_commit
  assert_eq "" "$(manifest_get_hash 'gone.md')" "commit persists removal"
}

run_tests "$@"
