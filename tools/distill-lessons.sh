#!/usr/bin/env bash
# Distills LESSONS.md files from archived features into .claude/SEMANTIC_MEMORY.md.
# Usage: agentic-kit/tools/distill-lessons.sh  (from project root)
#
# Reads all .artefacts/archive/*/LESSONS.md files and uses the Claude CLI to
# produce deduplicated, ranked heuristics appended to .claude/SEMANTIC_MEMORY.md.
#
# Requires: claude CLI on PATH.
# Run from project root.

set -euo pipefail

ARTEFACTS="${ARTEFACTS_DIR:-.artefacts}"
ARCHIVE_DIR="$ARTEFACTS/archive"
MEMORY_FILE="$ARTEFACTS/SEMANTIC_MEMORY.md"

if [ ! -d "$ARCHIVE_DIR" ]; then
  echo "No archive directory found ($ARCHIVE_DIR). Run the pipeline first."
  exit 0
fi

# Collect all LESSONS.md files from the archive
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

echo "Found ${#lessons_files[@]} LESSONS.md file(s)."

# Concatenate all lessons into a temp file
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for f in "${lessons_files[@]}"; do
  cat "$f" >> "$tmp"
  echo "" >> "$tmp"
done

# Build existing memory context (avoid duplicating already-distilled entries)
existing_context=""
if [ -f "$MEMORY_FILE" ]; then
  existing_context="Existing SEMANTIC_MEMORY.md (already distilled — do not duplicate):
---
$(cat "$MEMORY_FILE")
---
"
fi

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

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI not on PATH. Install Claude Code or run distillation manually."
  echo "Raw lessons are in: ${lessons_files[*]}"
  exit 1
fi

echo "Distilling with Claude..."
mkdir -p "$ARTEFACTS"
new_section=$(claude -p --allowedTools '' "$distill_prompt" 2>/dev/null)

if [ -z "$new_section" ]; then
  echo "Distillation returned empty output. No changes made."
  exit 1
fi

# Append to SEMANTIC_MEMORY.md
{
  if [ -f "$MEMORY_FILE" ]; then
    echo ""
  fi
  printf '%s\n' "$new_section"
} >> "$MEMORY_FILE"

echo "Done. Appended to $MEMORY_FILE"
echo "Review the new section, then commit if it looks good."
