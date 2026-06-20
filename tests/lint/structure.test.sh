#!/usr/bin/env bash
# Structural guards over the shipped product (agents, skills, docs). These read
# the real kit files — they assert invariants about what we ship, not runtime
# behaviour.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

# --- Frontmatter helpers --------------------------------------------------
# Echo the value of `key:` from the YAML frontmatter (between the first two ---).
_frontmatter_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    NR==1 && $0!="---" { exit }
    NR==1 { infm=1; next }
    infm && $0=="---" { exit }
    infm && $0 ~ "^"k":" { sub("^"k":[[:space:]]*",""); print; exit }
  ' "$file"
}

test_every_agent_has_valid_frontmatter() {
  local f name
  for f in "$KIT_ROOT"/agents/*.md; do
    [ -f "$f" ] || continue
    assert_eq "---" "$(head -n1 "$f")" "$(basename "$f"): starts with frontmatter"
    name=$(_frontmatter_value "$f" name)
    assert_ne "" "$name" "$(basename "$f"): has name:"
    assert_ne "" "$(_frontmatter_value "$f" description)" "$(basename "$f"): has description:"
    # name must match the filename stem.
    assert_eq "$(basename "$f" .md)" "$name" "$(basename "$f"): name matches filename"
  done
}

test_every_skill_has_valid_frontmatter() {
  local d f name
  for d in "$KIT_ROOT"/skills/*/; do
    f="${d}SKILL.md"
    assert_file_exists "$f" "$(basename "$d"): has SKILL.md"
    [ -f "$f" ] || continue
    assert_eq "---" "$(head -n1 "$f")" "$(basename "$d")/SKILL.md: starts with frontmatter"
    name=$(_frontmatter_value "$f" name)
    assert_ne "" "$name" "$(basename "$d"): skill has name:"
    assert_ne "" "$(_frontmatter_value "$f" description)" "$(basename "$d"): skill has description:"
    assert_eq "$(basename "${d%/}")" "$name" "$(basename "$d"): skill name matches directory"
  done
}

test_no_plugin_dependency_in_shipped_artifacts() {
  # Kit must be self-contained: never reference `superpowers` or other plugin
  # skills from shipped agents/skills/templates/docs. (See memory:
  # no-plugin-dependency.) Tests/ and this guard itself are excluded.
  local hits
  hits=$(grep -rIil --exclude-dir=tests --exclude-dir=.git \
           -e 'superpowers' \
           "$KIT_ROOT/agents" "$KIT_ROOT/skills" "$KIT_ROOT/templates" \
           "$KIT_ROOT/autoresearch" "$KIT_ROOT/README.md" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    fail "plugin reference found in shipped artifacts:"
    printf '        %s\n' $hits >&2
  fi
}

test_managed_block_markers_are_balanced() {
  # lib.sh defines paired begin/end markers; render output must contain both.
  source "$KIT_ROOT/shared/lifecycle/tools/lib.sh"
  local out; out=$(talaka_block_render ".tlk/PIPELINE.md")
  assert_contains "$out" "$TALAKA_BLOCK_BEGIN"
  assert_contains "$out" "$TALAKA_BLOCK_END"
  out=$(talaka_gitignore_render)
  assert_contains "$out" "$TALAKA_GITIGNORE_BEGIN"
  assert_contains "$out" "$TALAKA_GITIGNORE_END"
}

test_shell_scripts_are_syntactically_valid() {
  # bash -n every tracked *.sh under the kit (cheap parse check).
  local f bad=0
  while IFS= read -r f; do
    bash -n "$f" 2>/dev/null || { fail "syntax error: ${f#"$KIT_ROOT"/}"; bad=1; }
  done < <(find "$KIT_ROOT" -name '*.sh' -not -path '*/.git/*' -type f)
  [ "$bad" -eq 0 ] || true
}

run_tests "$@"
