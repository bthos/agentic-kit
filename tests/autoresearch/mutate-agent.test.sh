#!/usr/bin/env bash
# Tests for autoresearch/tools/mutate-agent.sh — specifically its output-guard
# logic (empty output, description-instead-of-file, no-op), which protects the
# ratchet from unusable proposals. The `claude` CLI is shadowed by a fake on
# PATH that echoes the contents of $FAKE_OUT, so no network/LLM is involved.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

MUTATE="$KIT_ROOT/autoresearch/tools/mutate-agent.sh"

# Build a project with: a fake `claude` on PATH, program.md, and a target file.
# Echoes the project root. The target's content is the 2nd arg.
_setup() {
  local target_content="$1"
  local proj; proj=$(make_tmp_project)
  local art="$proj/.akt"
  mkdir -p "$art/autoresearch" "$proj/.claude/agents" "$proj/bin"
  printf 'λ = 0.3\nINVARIANTS: do not break things.\n' > "$art/autoresearch/program.md"
  printf '%s' "$target_content" > "$proj/.claude/agents/cmok.md"

  # Fake claude: consume the prompt, emit $FAKE_OUT file contents (if any).
  cat > "$proj/bin/claude" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
if [ -n "${FAKE_OUT:-}" ] && [ -f "$FAKE_OUT" ]; then cat "$FAKE_OUT"; fi
EOF
  chmod +x "$proj/bin/claude"
  printf '%s' "$proj"
}

# _mutate PROJ → runs mutate-agent with fake claude on PATH; rc preserved.
_mutate() {
  local proj="$1"
  ( cd "$proj" && PATH="$proj/bin:$PATH" ARTEFACTS_DIR="$proj/.akt" \
      bash "$MUTATE" --target .claude/agents/cmok.md --round-id rt )
}

test_empty_output_aborts() {
  local proj; proj=$(_setup $'ORIGINAL CONTENT\n')
  : > "$proj/empty.txt"; export FAKE_OUT="$proj/empty.txt"
  _mutate "$proj" >/dev/null 2>&1 && fail "empty mutation should abort non-zero" || true
  unset FAKE_OUT
}

test_description_text_rejected() {
  local proj; proj=$(_setup $'ORIGINAL CONTENT\n')
  printf 'Here is the proposed change:\n- tighten the rule\n' > "$proj/desc.txt"
  export FAKE_OUT="$proj/desc.txt"
  local out rc
  out=$(_mutate "$proj" 2>&1); rc=$?
  unset FAKE_OUT
  assert_ne "0" "$rc" "description-text output is rejected"
  assert_contains "$out" "description text" "guard explains the rejection"
}

test_noop_mutation_rejected() {
  # Proposal identical to baseline → refused (cmp -s).
  local proj; proj=$(_setup $'SAME CONTENT\n')
  printf 'SAME CONTENT\n' > "$proj/same.txt"; export FAKE_OUT="$proj/same.txt"
  local out rc
  out=$(_mutate "$proj" 2>&1); rc=$?
  unset FAKE_OUT
  assert_ne "0" "$rc" "no-op mutation rejected"
  assert_contains "$out" "no change" "guard explains the no-op"
}

test_valid_mutation_succeeds() {
  local proj; proj=$(_setup $'ORIGINAL CONTENT\n')
  printf 'ORIGINAL CONTENT\nAdded one concrete guardrail rule.\n' > "$proj/good.txt"
  export FAKE_OUT="$proj/good.txt"
  local out rc
  out=$(_mutate "$proj" 2>&1); rc=$?
  unset FAKE_OUT
  assert_eq "0" "$rc" "valid mutation exits 0"
  assert_eq "rt" "$out" "prints the round id on success"
  assert_file_exists "$proj/.akt/autoresearch/variants/rt/proposal/.claude/agents/cmok.md" "proposal saved"
  assert_file_contains "$proj/.akt/autoresearch/variants/rt/baseline/.claude/agents/cmok.md" "ORIGINAL CONTENT" "baseline snapshotted"
}

test_missing_program_md_errors() {
  local proj; proj=$(_setup $'X\n')
  rm -f "$proj/.akt/autoresearch/program.md"
  _mutate "$proj" >/dev/null 2>&1 && fail "missing program.md should error" || true
}

run_tests "$@"
