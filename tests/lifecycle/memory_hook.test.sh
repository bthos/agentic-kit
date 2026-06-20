#!/usr/bin/env bash
# Tests for memory/tools/memory-hook.sh — the opt-in Stop hook in .claude/settings.json.
# Installs/removes only the kit's own hook; must preserve all other settings.
# Requires jq (skips cleanly without it, mirroring the script's own degrade path).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

have_jq() { command -v jq >/dev/null 2>&1; }

# Lightweight sandbox: memory-hook.sh sources shared/lifecycle/tools/lib.sh and
# resolves PROJECT_ROOT as the kit's parent, so stage shared/ + memory/.
_proj() {
  local proj; proj=$(make_tmp_project)
  mkdir -p "$proj/talaka"
  cp -r "$KIT_ROOT/shared" "$KIT_ROOT/memory" "$proj/talaka/"
  printf '%s' "$proj"
}
_hook() { ( cd "$1" && bash talaka/memory/tools/memory-hook.sh "${@:2}" ); }
_settings() { printf '%s/.claude/settings.json' "$1"; }

test_install_creates_hook() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  _hook "$proj" >/dev/null 2>&1
  local s; s=$(_settings "$proj")
  assert_file_exists "$s" "settings.json created"
  local has; has=$(jq '[ .hooks.Stop[]?.hooks[]?.command ] | any(contains("memory/tools/tick.sh"))' "$s")
  assert_eq "true" "$has" "Stop hook references tick.sh"
}

test_install_is_idempotent() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  _hook "$proj" >/dev/null 2>&1
  _hook "$proj" >/dev/null 2>&1
  local n; n=$(jq '[ .hooks.Stop[]?.hooks[]?.command | select(contains("tick.sh")) ] | length' "$(_settings "$proj")")
  assert_eq "1" "$n" "hook installed exactly once on re-run"
}

test_install_preserves_existing_settings() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  mkdir -p "$proj/.claude"
  cat > "$(_settings "$proj")" <<'EOF'
{ "statusLine": { "type": "command", "command": "bash sl" },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "echo mine" } ] } ] } }
EOF
  _hook "$proj" >/dev/null 2>&1
  local s; s=$(_settings "$proj")
  assert_eq "bash sl" "$(jq -r '.statusLine.command' "$s")" "statusLine preserved"
  local mine; mine=$(jq '[ .hooks.Stop[]?.hooks[]?.command ] | any(.=="echo mine")' "$s")
  assert_eq "true" "$mine" "user hook preserved"
}

test_remove_deletes_only_our_hook() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  mkdir -p "$proj/.claude"
  cat > "$(_settings "$proj")" <<'EOF'
{ "statusLine": { "type": "command", "command": "bash sl" },
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "echo mine" } ] } ] } }
EOF
  _hook "$proj" >/dev/null 2>&1            # add ours alongside the user's
  _hook "$proj" --remove >/dev/null 2>&1   # remove ours
  local s; s=$(_settings "$proj")
  local ours; ours=$(jq '[ .hooks.Stop[]?.hooks[]?.command ] | any(contains("tick.sh"))' "$s")
  assert_eq "false" "$ours" "our hook removed"
  local mine; mine=$(jq '[ .hooks.Stop[]?.hooks[]?.command ] | any(.=="echo mine")' "$s")
  assert_eq "true" "$mine" "user hook and other settings preserved"
  assert_eq "bash sl" "$(jq -r '.statusLine.command' "$s")" "statusLine preserved"
}

test_remove_when_sole_hook_cleans_up() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  _hook "$proj" >/dev/null 2>&1            # fresh file, only our hook
  _hook "$proj" --remove >/dev/null 2>&1
  # hooks object should be gone (no dangling empty Stop array).
  local hk; hk=$(jq 'has("hooks")' "$(_settings "$proj")")
  assert_eq "false" "$hk" "empty hooks object cleaned up"
}

test_remove_without_settings_is_noop() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  _hook "$proj" --remove >/dev/null 2>&1 || fail "remove with no settings.json should exit 0"
  assert_file_absent "$(_settings "$proj")" "no settings.json created by a no-op remove"
}

test_dry_run_install_writes_nothing() {
  have_jq || { skip_test "jq absent"; return; }
  local proj; proj=$(_proj)
  _hook "$proj" --dry-run >/dev/null 2>&1
  assert_file_absent "$(_settings "$proj")" "dry-run install wrote nothing"
}

run_tests "$@"
