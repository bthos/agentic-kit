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

test_no_agent_to_agent_invocation_in_shipped_prompts() {
  # Coordinator-driven routing: a worker (agent or skill) does its task, appends
  # a return entry to handoff-log.md, and returns. Only the coordinator invokes
  # agents. Shipped prompts must therefore never instruct an agent to launch
  # another one. Naming an agent as a *recommendation* is fine — calling one is
  # not, so these patterns match imperatives, not mentions.
  local pat hits
  local -a patterns=(
    'auto-invoke'
    '[Aa]uto invoke'
    '[Uu]se the \*\*Agent tool\*\*'
    '[Uu]se the Agent tool'
    '[Ll]aunch (both )?(agent|agents) `'
    '[Ll]aunch the Agent tool'
    '[Vv]ia the Task tool'
    '[Rr]e-invoke `?@'
    '[Ii]mmediately invoke'
  )
  # Prohibitions are themselves phrased with these words ("Never auto-invoke…"),
  # so drop any hit whose line carries a negation marker. What survives is an
  # imperative — the thing we actually ban.
  local negated='[Nn]ever|[Dd]o not|[Dd]oes not|[Dd]on.t|must not|[Nn]o agent|without'
  for pat in "${patterns[@]}"; do
    hits=$(grep -rInE --exclude-dir=tests --exclude-dir=.git "$pat" \
             "$KIT_ROOT/agents" "$KIT_ROOT/skills" "$KIT_ROOT/templates" 2>/dev/null \
           | grep -vE "$negated" || true)
    if [ -n "$hits" ]; then
      fail "agent-to-agent invocation instruction found (pattern: $pat):"
      printf '        %s\n' "$hits" >&2
    fi
  done
}

test_every_agent_states_the_no_invocation_rule() {
  # Every shipped agent prompt must carry the rule explicitly — a worker that
  # only inherits it from PIPELINE.md loses it the moment it runs with a
  # trimmed context.
  local f
  for f in "$KIT_ROOT"/agents/*.md; do
    [ -f "$f" ] || continue
    grep -qiE 'do not invoke|does not invoke|never .*(launch|invoke).*(agent|skill)' "$f" \
      || fail "$(basename "$f"): missing an explicit 'do not invoke another agent' rule"
  done
}

test_every_agent_documents_progress_entries() {
  # A worker's context dies when it returns, so partial results ("built but
  # untested", "suite ran, 3 failures") only survive if it logged them while
  # still running. Every shipped agent prompt must carry the progress-entry
  # instruction — inheriting it from PIPELINE.md is lost on a trimmed context.
  local f
  for f in "$KIT_ROOT"/agents/*.md; do
    [ -f "$f" ] || continue
    grep -qE '\[context\] progress|\] progress$|progress entry|Progress entries' "$f" \
      || fail "$(basename "$f"): missing the progress-entry instruction"
  done
}

test_progress_entry_format_has_no_arrow_or_recommend() {
  # The arrow means "I have returned" and Recommend: is routing data; a mid-run
  # entry has neither. Catch a template block that starts a progress header and
  # then carries either.
  local f hits
  for f in "$KIT_ROOT"/agents/*.md "$KIT_ROOT"/skills/*/SKILL.md \
           "$KIT_ROOT"/skills/*/templates/handoff-log.md \
           "$KIT_ROOT"/templates/PIPELINE.md.template; do
    [ -f "$f" ] || continue
    hits=$(awk '
      /^## .*progress[[:space:]]*$/ { inblock=1; hdr=$0; hdrline=NR
        if ($0 ~ /→ Coordinator/) print FILENAME": "NR": progress header carries the arrow"
        next }
      inblock && /^(Recommend|Why):/ { print FILENAME": "NR": progress entry carries "$1; inblock=0; next }
      inblock && /^(##|```|$)/ { inblock=0 }
    ' "$f")
    [ -z "$hits" ] || fail "$hits"
  done
}

test_cmok_does_not_run_full_regression() {
  # Full regression is Bagnik's gate. Cmok running it on every build and every
  # fix-loop iteration is the pipeline's largest avoidable cost.
  local f="$KIT_ROOT/agents/cmok.md"
  grep -qiE 'do not run the full regression' "$f" \
    || fail "cmok.md: missing the explicit 'do not run the full regression suite' rule"
  grep -qiE 'focused test|focused tests|Focused test command' "$f" \
    || fail "cmok.md: missing the focused-test instruction"
}

test_bagnik_owns_full_regression() {
  local f="$KIT_ROOT/agents/bagnik.md"
  grep -qiE 'full.{0,15}(test suite|suite|regression)' "$f" \
    || fail "bagnik.md: no longer states that it runs the full suite"
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
