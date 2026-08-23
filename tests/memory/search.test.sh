#!/usr/bin/env bash
# Tests for memory/tools/search.sh — the retrieval entry point. These exercise
# the behaviour regardless of which backend (python TF-IDF or pure-shell) runs,
# except where noted. The py-vs-bash parity is covered separately by
# memory/tools/test-search-parity.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

SEARCH="$KIT_ROOT/memory/tools/search.sh"

_seed() {
  local art; art="$(make_tmp_project)/.tlk"
  mkdir -p "$art/memory"
  cat > "$art/memory/system.md" <<'EOF'
# System

- The deployment pipeline uses blue-green rollouts on Kubernetes.
- Database migrations run automatically before each release.
EOF
  cat > "$art/memory/preferences.md" <<'EOF'
# Preferences

- Prefer small, focused pull requests.
EOF
  printf '%s' "$art"
}
_run() { ARTEFACTS_DIR="$1" bash "$SEARCH" "${@:2}"; }

test_finds_relevant_chunk() {
  local art; art=$(_seed)
  local out; out=$(_run "$art" "kubernetes deployment" 2>&1)
  assert_contains "$out" "blue-green" "surfaces the relevant system fact"
}

test_empty_query_errors() {
  local art; art=$(_seed)
  ( ARTEFACTS_DIR="$art" bash "$SEARCH" >/dev/null 2>&1 ) && fail "empty query should exit non-zero" || true
}

test_no_matches_message() {
  local art; art=$(_seed)
  local out; out=$(_run "$art" "zzqqxx nonexistent term" 2>&1)
  # Either backend should produce no ranked hit for a nonsense query.
  assert_not_contains "$out" "blue-green" "nonsense query returns no real hit"
}

test_json_output_is_parseable() {
  local art; art=$(_seed)
  local out; out=$(_run "$art" "migrations release" --json 2>&1)
  assert_contains "$out" '"file"' "json mode emits file field"
  # Validate each non-empty line is real JSON when python3 is available.
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "$out" | python3 -c '
import sys, json
for line in sys.stdin:
    line = line.strip()
    if line:
        json.loads(line)
' || fail "json output did not parse"
  fi
}

test_layer_filter_restricts_scope() {
  local art; art=$(_seed)
  # Restricting to l3 still includes preferences/system; restricting away from a
  # layer should not crash and should still return results from allowed layers.
  local out; out=$(_run "$art" "pull requests" --layer l3 2>&1)
  assert_contains "$out" "pull requests" "l3 filter still finds L3 content"
}

test_top_k_limits_results() {
  local art; art=$(_seed)
  # With top-k 1, at most one ranked block header ("[1]") and no "[2]".
  local out; out=$(_run "$art" "release pipeline requests" --top-k 1 2>&1)
  assert_not_contains "$out" "[2]" "top-k 1 returns a single ranked block (shell backend)"
}

run_tests "$@"
