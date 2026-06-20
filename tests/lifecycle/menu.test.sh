#!/usr/bin/env bash
# Tests for kit.sh — the launcher's machine-readable surface and the
# optional-components registry. The interactive menu/submenu is TTY-gated, so we
# assert what's testable headlessly: --list-json, --help, and that every
# component the submenu can install points at a real script.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# kit.sh derives PROJECT_ROOT as its own parent, so run a copy from a
# sandbox to avoid touching the real repo.
_proj() {
  local proj; proj=$(make_tmp_project)
  mkdir -p "$proj/talaka"
  cp "$KIT_ROOT/kit.sh" "$proj/talaka/"
  printf '%s' "$proj"
}
_tlk() { bash "$1/talaka/kit.sh" "${@:2}"; }

test_list_json_is_valid_and_has_components() {
  local proj; proj=$(_proj)
  local out; out=$(_tlk "$proj" --list-json 2>&1) || fail "--list-json exited non-zero"
  assert_contains "$out" '"key":"components"' "components launcher present in registry"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$out" | python3 -c 'import sys,json; json.load(sys.stdin)' || fail "--list-json is not valid JSON"
  fi
}

test_help_lists_components() {
  local proj; proj=$(_proj)
  local out; out=$(_tlk "$proj" --help 2>&1)
  assert_contains "$out" "components" "help mentions the components action"
}

test_components_menu_requires_tty() {
  # Single-action mode with no TTY must refuse, not hang.
  local proj; proj=$(_proj)
  # Needs stage >= 1; without init it's stage 0, so this also exercises the
  # stage guard. Either way it must exit non-zero (not block on read).
  _tlk "$proj" components </dev/null >/dev/null 2>&1 && fail "components without TTY/stage should exit non-zero" || true
}

test_component_scripts_exist() {
  # Guard against registry rot: the install/remove commands must reference real,
  # executable scripts shipped in the kit.
  assert_file_exists "$KIT_ROOT/statusline/tools/install-statusline.sh" "statusline installer exists"
  assert_file_exists "$KIT_ROOT/autoresearch/run.sh"          "autoresearch runner exists"
  assert_file_exists "$KIT_ROOT/memory/tools/memory-hook.sh"         "memory-hook script exists"
}

run_tests "$@"
