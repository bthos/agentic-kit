#!/usr/bin/env bash
# Distills LESSONS.md files from archived features into the layered memory tree.
# Usage: agentic-kit/tools/distill-lessons.sh [--target=memory|agents|both] [--legacy]
#
#   --target=memory  (default) Append schema-compliant entries into today's L2
#                              daily file (.artefacts/memory/YYYY-MM-DD.md), then
#                              run memory-promote.sh so the 2-strike rule, supersedes
#                              resolver, and L4 root index update automatically.
#   --target=agents            Write proposed per-agent patches to
#                              .artefacts/proposed-patches/<agent>.md so a human (or
#                              `apply-patches.sh`) can review and merge them into the
#                              installed agent copies (self-improvement Layer 2).
#   --target=both              Run both pipelines.
#
#   --legacy                   Append a flat section to .artefacts/SEMANTIC_MEMORY.md
#                              instead of using the layered memory tree (kept for
#                              projects that have not migrated yet).
#
# Reads all .artefacts/archive/*/LESSONS.md files and uses the Claude CLI.
# Requires: claude CLI on PATH.
# Run from project root.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTEFACTS="${ARTEFACTS_DIR:-.artefacts}"
ARCHIVE_DIR="$ARTEFACTS/archive"
MEM_DIR="$ARTEFACTS/memory"
LEGACY_MEMORY_FILE="$ARTEFACTS/SEMANTIC_MEMORY.md"
PATCHES_DIR="$ARTEFACTS/proposed-patches"

TARGET="memory"
LEGACY=false
for _arg in "$@"; do
  case "$_arg" in
    --target=*) TARGET="${_arg#--target=}" ;;
    --legacy)   LEGACY=true ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [[ ! "$TARGET" =~ ^(memory|agents|both)$ ]]; then
  echo "Invalid --target='$TARGET' (use: memory | agents | both)" >&2
  exit 1
fi

if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "No archive directory found ($ARCHIVE_DIR). Run the pipeline first."
  exit 0
fi

lessons_files=()
for dir in "$ARCHIVE_DIR"/*/; do
  [ -d "$dir" ] || continue
  f="${dir}LESSONS.md"
  [ -f "$f" ] && lessons_files+=("$f")
done

if [ ${#lessons_files[@]} -eq 0 ]; then
  echo "No LESSONS.md files found in $ARCHIVE_DIR. Nothing to distill."
  exit 0
fi

echo "Found ${#lessons_files[@]} LESSONS.md file(s). Target: $TARGET"

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI not on PATH. Install Claude Code or run distillation manually." >&2
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for f in "${lessons_files[@]}"; do
  cat "$f" >> "$tmp"
  echo "" >> "$tmp"
done

# ---------------------------------------------------------------------------
# Target 1 (default): write schema-compliant entries into today's L2 daily file
# ---------------------------------------------------------------------------
distill_to_memory() {
  if $LEGACY; then
    distill_to_legacy_memory
    return
  fi

  # Make sure the memory tree exists; init silently if missing.
  if [ ! -d "$MEM_DIR" ]; then
    if [ -x "$KIT_DIR/tools/memory-init.sh" ]; then
      ( cd "$(pwd)" && "$KIT_DIR/tools/memory-init.sh" >/dev/null )
    else
      mkdir -p "$MEM_DIR"
    fi
  fi

  local today daily_file existing_context
  today=$(date +%Y-%m-%d)
  daily_file="$MEM_DIR/$today.md"
  [ -f "$daily_file" ] || printf '# Daily memory — %s (L2)\n\n## Observations\n' "$today" > "$daily_file"

  existing_context=""
  if [ -f "$ARTEFACTS/MEMORY.md" ]; then
    existing_context="Current root summary (.artefacts/MEMORY.md) — do NOT duplicate facts already in the high-confidence sections:
---
$(cat "$ARTEFACTS/MEMORY.md")
---
"
  fi

  local distill_prompt
  distill_prompt="You are distilling project-specific lessons from completed feature pipeline runs into the layered memory tree.

Below are LESSONS.md entries from archived features:

---
$(cat "$tmp")
---

${existing_context}Produce a list of schema-compliant memory entries to APPEND to today's daily file.

The schema (see agentic-kit/templates/memory/SCHEMA.md) is exactly:

- id: pending
  decided: $today
  entity_type: <one of: person, project, file, tool, library, pattern, anti-pattern, decision>
  entities: [<short names, optional>]
  confidence: medium
  source: archive/<feature-id>/LESSONS.md
  text: |
    <one or two concrete sentences — specific, actionable, verifiable>

Rules:
- Output ONLY a sequence of bullet blocks of the shape above. No preamble, no markdown headings, no fenced code blocks.
- Use 'id: pending' literally — memory-promote.sh will hash it.
- Use the smallest, most concrete 'text:' you can. Reference real files / commands / artefacts where useful.
- Prefer 'pattern' for repeatable ways of doing things, 'anti-pattern' for things to avoid, 'decision' for explicit choices, 'tool'/'library' for new dependencies, 'project' for canonical per-feature summaries.
- Skip lessons already captured in the root summary above.
- Maximum 15 entries total; quality over quantity.
- If there is nothing new to add, output the single line: NO_ENTRIES"

  echo "Distilling to $daily_file…"
  local new_entries
  new_entries=$(claude -p --allowedTools '' "$distill_prompt" 2>/dev/null || true)

  if [ -z "$new_entries" ] || [[ "$new_entries" =~ ^NO_ENTRIES[[:space:]]*$ ]]; then
    echo "Nothing new to add to today's daily file."
    return
  fi

  {
    printf '\n## Distilled from archive (%s)\n\n' "$(date -u +%H:%MZ)"
    printf '%s\n' "$new_entries"
  } >> "$daily_file"
  echo "Appended schema entries to $daily_file."

  # Promote (hash + 2-strike + supersedes + L4 regen)
  if [ -x "$KIT_DIR/tools/memory-promote.sh" ]; then
    ( cd "$(pwd)" && "$KIT_DIR/tools/memory-promote.sh" ) || true
  fi
}

# Back-compat: write to flat SEMANTIC_MEMORY.md (deprecated; kept under --legacy)
distill_to_legacy_memory() {
  local existing_context=""
  if [ -f "$LEGACY_MEMORY_FILE" ]; then
    existing_context="Existing SEMANTIC_MEMORY.md (already distilled — do not duplicate):
---
$(cat "$LEGACY_MEMORY_FILE")
---
"
  fi

  local distill_prompt
  distill_prompt="You are distilling project-specific lessons from completed feature pipeline runs into a permanent memory file.

Below are LESSONS.md entries from archived features:

---
$(cat "$tmp")
---

${existing_context}Produce a new section to APPEND (not replace) to the existing file.

Rules:
- Only include lessons not already captured in the existing memory
- Group by tag: [pattern], [anti-pattern], [decision], [shortcut]
- Keep each bullet specific and actionable — no vague generalities
- Do NOT reference scoring, evaluation criteria, or self-improvement metrics
- Maximum 20 new bullets total; prefer quality over quantity
- Start with: ## Distilled lessons ($(date +%Y-%m-%d))

Output only the markdown section — no preamble, no explanation."

  echo "(legacy) Distilling to $LEGACY_MEMORY_FILE…"
  mkdir -p "$ARTEFACTS"
  local new_section
  new_section=$(claude -p --allowedTools '' "$distill_prompt" 2>/dev/null || true)

  if [ -z "$new_section" ]; then
    echo "Distillation returned empty output. No changes to memory."
    return
  fi

  {
    [ -f "$LEGACY_MEMORY_FILE" ] && echo ""
    printf '%s\n' "$new_section"
  } >> "$LEGACY_MEMORY_FILE"
  echo "Appended to $LEGACY_MEMORY_FILE."
}

# ---------------------------------------------------------------------------
# Target 2: proposed per-agent patches (Layer 2 self-improvement)
# ---------------------------------------------------------------------------
distill_to_agents() {
  mkdir -p "$PATCHES_DIR"

  # Collect installed agent file list so the LLM knows which roles exist
  agent_list=""
  for dir in "$PROJECT_ROOT/.claude/agents" ".claude/agents"; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .md)
      agent_list+="- $name"$'\n'
    done < <(find "$dir" -maxdepth 1 -name '*.md' 2>/dev/null)
    break
  done
  [ -z "$agent_list" ] && agent_list="- bagnik"$'\n'"- cmok"$'\n'"- mokash"$'\n'"- zlydni"$'\n'

  local patch_prompt
  patch_prompt="You are proposing project-specific behavioural patches for AI development agents based on lessons from completed feature pipeline runs.

Lessons collected:
---
$(cat "$tmp")
---

Available agents in this project:
$agent_list

For each agent that should change its behaviour based on these lessons, output a fenced block:

\`\`\`patch:<agent-name>
### Project specifics ($(date +%Y-%m-%d))
- <one concrete rule>
- <another concrete rule>
\`\`\`

Rules:
- Only emit a block for an agent if there is a clear, repeatable lesson for that role.
- Keep each rule actionable and concrete — reference real artefacts, commands, or patterns from the lessons.
- 1–6 rules per agent, max.
- Do NOT propose patches that contradict the agent's existing role or guardrails.
- Do NOT touch anything related to scoring, judging, or metrics — those belong to the autoresearch loop.
- If no agent should change, output the single line: NO_PATCHES

Output only the fenced patch blocks (or NO_PATCHES). No preamble."

  echo "Proposing per-agent patches to $PATCHES_DIR/…"
  local raw
  raw=$(claude -p --allowedTools '' "$patch_prompt" 2>/dev/null || true)

  if [ -z "$raw" ] || [[ "$raw" =~ NO_PATCHES ]]; then
    echo "No actionable agent patches proposed."
    return
  fi

  # Split fenced blocks into per-agent files
  awk -v dir="$PATCHES_DIR" '
    /^```patch:/ {
      gsub(/^```patch:/, "")
      gsub(/[[:space:]]+$/, "")
      agent=$0
      file=dir "/" agent ".md"
      writing=1
      print "<!-- proposed patch for agent: " agent " (review with apply-patches.sh) -->" > file
      next
    }
    /^```$/ && writing==1 { writing=0; next }
    writing==1 { print >> file }
  ' <<<"$raw"

  echo "Wrote proposals to $PATCHES_DIR/. Review with: agentic-kit/tools/apply-patches.sh"
}

PROJECT_ROOT="$(pwd)"

case "$TARGET" in
  memory) distill_to_memory ;;
  agents) distill_to_agents ;;
  both)   distill_to_memory; distill_to_agents ;;
esac

echo "Done."
