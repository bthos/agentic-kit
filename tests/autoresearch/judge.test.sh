#!/usr/bin/env bash
# Tests for autoresearch/tools/judge.sh — placeholder substitution, judge-command
# resolution from PROJECT.md, and verdict sanitization. The LLM is replaced by a
# scripted fake judge command so the result is deterministic.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

JUDGE="$KIT_ROOT/autoresearch/tools/judge.sh"

# Set up an artefacts dir whose PROJECT.md points the judge at $cmd.
_art_with_judge() {
  local cmd="$1"
  local art; art="$(make_tmp_project)/.akt"
  mkdir -p "$art"
  printf -- '- **Judge command:** `%s`\n' "$cmd" > "$art/PROJECT.md"
  printf '%s' "$art"
}

test_verdict_one_when_judge_emits_one() {
  local art; art=$(_art_with_judge "printf 1")
  local v; v=$(ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement "must greet" --output "Hello there" 2>/dev/null)
  assert_eq "1" "$v" "judge passes through a 1 verdict"
}

test_verdict_zero_when_judge_emits_zero() {
  local art; art=$(_art_with_judge "printf 0")
  local v; v=$(ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement "must greet" --output "irrelevant" 2>/dev/null)
  assert_eq "0" "$v" "judge passes through a 0 verdict"
}

test_nonbinary_verdict_sanitized_to_zero() {
  # program.md rule 5: uncertainty = failure. Anything not 0/1 → 0.
  local art; art=$(_art_with_judge "printf maybe")
  local v; v=$(ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement "x" --output "y" 2>/dev/null)
  assert_eq "0" "$v" "garbage verdict treated as failure"
}

test_prompt_substitution_reaches_judge() {
  # A fake judge that emits 1 only if the substituted prompt actually contains
  # both the requirement and output text — proving {{requirement}}/{{output}}
  # were filled in.
  local proj; proj=$(make_tmp_project)
  local art="$proj/.akt"; mkdir -p "$art"
  local fake="$proj/fakejudge.sh"
  cat > "$fake" <<'EOF'
#!/usr/bin/env bash
p=$(cat)
case "$p" in
  *REQ_TOKEN*OUT_TOKEN*|*OUT_TOKEN*REQ_TOKEN*) printf 1 ;;
  *) printf 0 ;;
esac
EOF
  chmod +x "$fake"
  printf -- '- **Judge command:** `bash %s`\n' "$fake" > "$art/PROJECT.md"
  local v; v=$(ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement "REQ_TOKEN" --output "OUT_TOKEN" 2>/dev/null)
  assert_eq "1" "$v" "both placeholders substituted into the prompt"
}

test_missing_output_errors() {
  local art; art=$(_art_with_judge "printf 1")
  ( ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement "only req" >/dev/null 2>&1 ) \
    && fail "missing --output should exit non-zero" || true
}

test_file_inputs_supported() {
  local proj; proj=$(make_tmp_project)
  local art="$proj/.akt"; mkdir -p "$art"
  printf -- '- **Judge command:** `printf 1`\n' > "$art/PROJECT.md"
  printf 'requirement from file' > "$proj/req.txt"
  printf 'output from file' > "$proj/out.txt"
  local v; v=$(ARTEFACTS_DIR="$art" bash "$JUDGE" --requirement-file "$proj/req.txt" --output-file "$proj/out.txt" 2>/dev/null)
  assert_eq "1" "$v" "--requirement-file / --output-file accepted"
}

run_tests "$@"
