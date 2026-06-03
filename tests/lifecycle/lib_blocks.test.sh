#!/usr/bin/env bash
# Unit tests for the managed-block helpers in tools/lib.sh
# (CLAUDE.md / AGENTS.md include block + .gitignore block).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"
source "$KIT_ROOT/tools/lib.sh"

test_render_contains_markers_and_pipeline() {
  local out
  out=$(agentic_block_render ".akt/PIPELINE.md")
  assert_contains "$out" "$AGENTIC_BLOCK_BEGIN" "render has begin marker"
  assert_contains "$out" "$AGENTIC_BLOCK_END"   "render has end marker"
  assert_contains "$out" "@.akt/PIPELINE.md"    "render has @include line"
  assert_contains "$out" ".akt/PIPELINE.md"     "render references pipeline path"
}

test_write_stub_creates_file_with_block() {
  local proj; proj=$(make_tmp_project)
  local f="$proj/CLAUDE.md"
  agentic_block_write_stub "$f" ".akt/PIPELINE.md"
  assert_file_exists "$f"
  assert_file_contains "$f" "$AGENTIC_BLOCK_BEGIN"
  assert_file_contains "$f" "$AGENTIC_BLOCK_END"
  # Title line derived from basename.
  assert_file_contains "$f" "# CLAUDE"
}

test_append_preserves_existing_content() {
  local proj; proj=$(make_tmp_project)
  local f="$proj/CLAUDE.md"
  printf '# My Project\n\nUser-written guidance here.\n' > "$f"
  agentic_block_append "$f" ".akt/PIPELINE.md"
  assert_file_contains "$f" "User-written guidance here."
  assert_file_contains "$f" "$AGENTIC_BLOCK_BEGIN"
  # The user content must come before the managed block.
  local user_ln block_ln
  user_ln=$(grep -n "User-written guidance" "$f" | head -1 | cut -d: -f1)
  block_ln=$(grep -nF "$AGENTIC_BLOCK_BEGIN" "$f" | head -1 | cut -d: -f1)
  [ "$user_ln" -lt "$block_ln" ] || fail "user content should precede managed block"
}

test_strip_removes_block_keeps_user_content() {
  local proj; proj=$(make_tmp_project)
  local f="$proj/CLAUDE.md"
  printf '# My Project\n\nKeep me above.\n' > "$f"
  agentic_block_append "$f" ".akt/PIPELINE.md"
  printf '\nKeep me below.\n' >> "$f"

  assert_ok agentic_block_present "$f"
  agentic_block_strip "$f"
  assert_file_not_contains "$f" "$AGENTIC_BLOCK_BEGIN" "block markers removed"
  assert_file_not_contains "$f" "@.akt/PIPELINE.md"     "include line removed"
  assert_file_contains "$f" "Keep me above."
  assert_file_contains "$f" "Keep me below."
}

test_strip_is_idempotent() {
  local proj; proj=$(make_tmp_project)
  local f="$proj/CLAUDE.md"
  agentic_block_write_stub "$f" ".akt/PIPELINE.md"
  agentic_block_strip "$f"   # first strip removes it
  # Second strip: no block present → returns non-zero, file unchanged.
  assert_fail agentic_block_present "$f"
  assert_fail agentic_block_strip "$f"
}

test_strip_trims_trailing_blank_lines() {
  local proj; proj=$(make_tmp_project)
  local f="$proj/CLAUDE.md"
  printf 'top\n' > "$f"
  agentic_block_append "$f" ".akt/PIPELINE.md"
  agentic_block_strip "$f"
  # File should not end with a run of blank lines.
  local last; last=$(tail -c 2 "$f")
  assert_ne $'\n\n' "$last" "no double trailing newline left after strip"
}

test_gitignore_render_strip_roundtrip() {
  local proj; proj=$(make_tmp_project)
  local gi="$proj/.gitignore"
  printf 'node_modules/\n' > "$gi"
  agentic_gitignore_render >> "$gi"
  assert_ok agentic_gitignore_present "$gi"
  assert_file_contains "$gi" ".akt/memory/"
  assert_file_contains "$gi" ".akt/.agentic-kit.files"

  agentic_gitignore_strip "$gi"
  assert_fail agentic_gitignore_present "$gi"
  assert_file_not_contains "$gi" "$AGENTIC_GITIGNORE_BEGIN"
  assert_file_contains "$gi" "node_modules/"   "user ignore lines preserved"
}

test_gitignore_honours_artefacts_dir_override() {
  # ARTEFACTS_NAME is captured at source time from ARTEFACTS_DIR; render reads
  # the live ARTEFACTS_NAME global, so overriding it changes the output.
  local saved="$ARTEFACTS_NAME"
  ARTEFACTS_NAME=".kit-state"
  local out; out=$(agentic_gitignore_render)
  assert_contains "$out" ".kit-state/memory/" "override reflected in gitignore"
  ARTEFACTS_NAME="$saved"
}

run_tests "$@"
