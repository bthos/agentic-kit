#!/usr/bin/env bash
# Fast unit tests for the 3-way-merge primitives in lib.sh (kit_strip_cr,
# kit_three_way_merge, kit_three_way_merge_tree, kit_render_diff). These call the
# helpers directly — no init.sh — so the whole file runs in well under a second.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
# Pull in the real kit helpers under test.
source "$KIT_ROOT/shared/lifecycle/tools/lib.sh"

_wd() { local d; d=$(mktemp -d "${TMPDIR:-/tmp}/tlk-mh.XXXXXX"); _TMP_DIRS+=("$d"); printf '%s' "$d"; }

# ---------------------------------------------------------------------------

test_strip_cr_removes_carriage_returns() {
  local d; d=$(_wd)
  printf 'A\r\nB\r\n' > "$d/crlf.txt"
  local out; out=$(kit_strip_cr "$d/crlf.txt")
  # Count CR *bytes* (git-bash `grep -c $'\r'` spuriously matches every line-end).
  assert_eq "0" "$(tr -cd '\r' < "$out" | wc -c | tr -dc '0-9')" "no CR left after strip"
  assert_eq "A" "$(sed -n '1p' "$out")" "content line 1 preserved"
  assert_eq "B" "$(sed -n '2p' "$out")" "content line 2 preserved"
}

test_merge_clean_when_edits_dont_overlap() {
  local d; d=$(_wd)
  printf 'A\nB\n'        > "$d/base"
  printf 'A\nB\nLOCAL\n' > "$d/local"     # local appended at end
  printf 'TOP\nA\nB\n'   > "$d/new"       # kit inserted at top
  kit_three_way_merge "$d/local" "$d/base" "$d/new" "$d/out"; local rc=$?
  assert_eq "0" "$rc" "non-overlapping edits merge clean"
  assert_file_contains     "$d/out" "LOCAL" "local edit kept"
  assert_file_contains     "$d/out" "TOP"   "kit edit applied"
  assert_file_not_contains "$d/out" "<<<<<<<" "no conflict markers"
}

test_merge_conflict_when_edits_overlap() {
  local d; d=$(_wd)
  printf 'A\nB\n'    > "$d/base"
  printf 'A\nB\nX\n' > "$d/local"
  printf 'A\nB\nY\n' > "$d/new"
  kit_three_way_merge "$d/local" "$d/base" "$d/new" "$d/out"; local rc=$?
  assert_eq "1" "$rc" "overlapping edits conflict"
  assert_file_contains "$d/out" "<<<<<<<" "conflict markers present"
  assert_file_contains "$d/out" "X" "local side present in conflict"
  assert_file_contains "$d/out" "Y" "kit side present in conflict"
}

test_merge_ignores_crlf_vs_lf() {
  local d; d=$(_wd)
  printf 'A\nB\n'     > "$d/base"     # LF
  printf 'A\r\nB\r\n' > "$d/local"    # CRLF, SAME content
  printf 'A\nB\nZ\n'  > "$d/new"      # LF + one new line
  kit_three_way_merge "$d/local" "$d/base" "$d/new" "$d/out"; local rc=$?
  assert_eq "0" "$rc" "CRLF-vs-LF is not a phantom conflict"
  assert_file_contains     "$d/out" "Z" "kit change lands"
  assert_file_not_contains "$d/out" "<<<<<<<" "no markers from line endings"
}

test_merge_tree_clean_union() {
  local d; d=$(_wd)
  mkdir -p "$d/base" "$d/local" "$d/new"
  printf 'A\nB\n'        > "$d/base/f1"
  printf 'A\nB\nL\n'     > "$d/local/f1";  printf 'x\n' > "$d/local/only_local"
  printf 'T\nA\nB\n'     > "$d/new/f1";    printf 'n\n' > "$d/new/only_new"
  kit_three_way_merge_tree "$d/local" "$d/base" "$d/new" "$d/out"; local rc=$?
  assert_eq "0" "$rc" "tree merges clean"
  assert_file_contains "$d/out/f1" "L" "per-file local edit kept"
  assert_file_contains "$d/out/f1" "T" "per-file kit edit applied"
  assert_file_exists   "$d/out/only_local" "local-only file kept"
  assert_file_exists   "$d/out/only_new"   "kit-added file pulled in"
}

test_merge_tree_kit_delete_of_unchanged_file() {
  local d; d=$(_wd)
  mkdir -p "$d/base" "$d/local" "$d/new"
  printf 'keep\n' > "$d/base/f1"; printf 'gone\n' > "$d/base/f2"
  printf 'keep\n' > "$d/local/f1"; printf 'gone\n' > "$d/local/f2"   # f2 unchanged locally
  printf 'keep\n' > "$d/new/f1"                                       # kit removed f2
  kit_three_way_merge_tree "$d/local" "$d/base" "$d/new" "$d/out"; local rc=$?
  assert_eq "0" "$rc" "delete of unchanged file is clean"
  assert_file_exists "$d/out/f1" "unrelated file kept"
  assert_file_absent "$d/out/f2" "kit deletion of unchanged file honoured"
}

test_render_diff_summarises_small_change() {
  local d; d=$(_wd)
  printf 'A\nB\nC\n'   > "$d/a"
  printf 'A\nB\nC\nD\n'> "$d/b"           # one added line
  local out; out=$(kit_render_diff "$d/a" "$d/b")
  assert_contains "$out" "+1 / -0" "one-line add reported as +1/-0"
}

test_render_diff_no_phantom_on_crlf() {
  local d; d=$(_wd)
  printf 'A\nB\n'     > "$d/a"            # LF
  printf 'A\r\nB\r\n' > "$d/b"            # CRLF, identical content
  local out; out=$(kit_render_diff "$d/a" "$d/b")
  assert_contains "$out" "+0 / -0" "CRLF-only difference summarised as no change"
}

run_tests "$@"
