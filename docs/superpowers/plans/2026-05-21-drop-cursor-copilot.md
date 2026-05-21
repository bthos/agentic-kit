# Drop Cursor and Copilot Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-05-21-drop-cursor-copilot-design.md`

**Goal:** Collapse the kit to a single Claude-shaped install target with `AGENTS.md` as the cross-IDE entry-point, removing all Cursor and GitHub Copilot generation code.

**Architecture:** Refactor outward from content (templates, agents, docs) to tooling (`lib.sh`, `init.sh`, `teardown.sh`, `update.sh`). Final phase smoke-tests fresh install, simulated upgrade, local-edit preservation, and teardown round-trip in a throwaway scratch dir.

**Tech Stack:** Bash 5+, ShellCheck, plain Markdown templates. No formal test framework — verification via bash smoke scripts and `tools/validate-config.sh`.

---

## File Structure

### Modified files

| File | Responsibility after refactor |
|------|-------------------------------|
| `tools/init.sh` | Single install target. Generate `.claude/agents/`, `.claude/skills/`, `.akt/`, `CLAUDE.md`, `AGENTS.md`, and managed `.gitignore` block. No `--ide` flag. |
| `tools/teardown.sh` | Strip include blocks from `CLAUDE.md` and `AGENTS.md`; remove `.claude/` agent and skill copies; strip `.gitignore` block; `--full-clean` sweeps `.akt/scratch/`. No Cursor / GitHub sections. |
| `tools/update.sh` | Refresh pipeline + agents + skills; legacy sweep removes manifest-matching `.cursor/` and `.github/` artefacts from prior installs. |
| `tools/lib.sh` | Helpers shared across `init.sh`, `update.sh`, `teardown.sh`. Receives `teardown_managed_file` and `teardown_managed_tree` (lifted from `teardown.sh`). Drops Cursor/Copilot-only comments and helpers. |
| `templates/PIPELINE.md.template` | IDE-agnostic. One setup command, no per-IDE invocation matrix. |
| `agents/*.md` | No `cursor_rule_name` / `cursor_subagent_name` frontmatter. No `cmok-build` references. IDE-agnostic invocation prose. |
| `skills/*/SKILL.md` | Same as agents. |
| `README.md` | "Supported IDEs" reduced to one sentence about AGENTS.md universality. Drops per-IDE setup steps. |
| `CHANGELOG.md` | New entry under `[Unreleased]` documenting the breaking change. |
| `autoresearch/run.sh` | Drop the `.cursor/agents` / `.cursor/skills` branches in its agent/skill enumeration loops. |
| `templates/autoresearch/program.md` | Drop "No Cursor" / "No Copilot" prose if present. |

### Untouched files (intentionally)

- `tools/bump-version.sh`, `tools/probe-project.sh`, `tools/distill-lessons.sh`, `tools/apply-patches.sh`, `tools/feature-status.sh`, `tools/validate-config.sh`, `tools/lean-claude.sh` — none invoke `--ide` or write to `.cursor/` / `.github/`.
- `agentic-kit.sh` — verified clean during brainstorming (`grep -n cursor|copilot|github|--ide` returns nothing).
- `memory/tools/*` and `templates/memory/*` — IDE-agnostic already.
- `templates/PROJECT.md.template` — no IDE references.

---

## Phase 1 — Content (low blast radius)

### Task 1: Make `templates/PIPELINE.md.template` IDE-agnostic

**Files:**
- Modify: `templates/PIPELINE.md.template`

- [ ] **Step 1: Identify all per-IDE blocks**

Run:
```bash
grep -n 'cursor\|copilot\|github\|--ide' templates/PIPELINE.md.template
```

Expected lines (currently): the layout tree (~36), "What each `--ide` produces" table (~41-48), "How to invoke (by IDE)" table (~95-104), "Mockups vs Cmok build" sentence (~94), Handoff Map footnote (~199). Note the exact line numbers from the grep output — line numbers shift after each edit.

- [ ] **Step 2: Collapse "Kit Setup (for agents)" section**

Replace lines ~9-20 (the four `--ide=` install commands and the "non-interactive flags" sentence that mentions IDE-specific behavior) with:

```markdown
To set up agentic-kit in a project, run from the **project root** (the directory that contains `agentic-kit/`):

`​``bash
agentic-kit/tools/init.sh --non-interactive
`​``

Non-interactive flags: `-n`, `--non-interactive`, `--yes`, or `-y`. The script prints a **`[AGENT ACTION REQUIRED]`** block instead of spawning a nested CLI to edit `.akt/PROJECT.md`.

**After the script exits, fill in `.akt/PROJECT.md` yourself:** inspect the project files (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, version files, etc.) and replace every `<placeholder>` with the correct value. Then run `agentic-kit/tools/validate-config.sh` to confirm all placeholders are resolved.
```

- [ ] **Step 3: Simplify the layout tree**

Replace the layout block at ~22-37 with:

```markdown
**Layout — minimally invasive (the goal):**

`​``
project root/
├── .akt/                          ← single home for kit-managed docs + state
│   ├── PIPELINE.md                ← canonical pipeline (kit-managed; refreshed on init)
│   ├── PROJECT.md                 ← project-specific config (you edit this)
│   ├── memory/                    ← layered memory (auto-managed)
│   ├── features/                  ← active feature folders (created per /vadavik)
│   ├── archive/                   ← completed features (moved by Zlydni)
│   └── scratch/                   ← ephemeral runtime files (auto-managed)
├── CLAUDE.md                      ← Claude Code entry-point with managed include block
├── AGENTS.md                      ← Cross-IDE entry-point with the same include block
├── .claude/                       ← agent + skill copies
└── .gitignore                     ← managed block ignores .akt/{memory,features,archive,scratch,…}
`​``

Everything kit-touched is either inside `.akt/`, inside `.claude/`, or wrapped in a removable `<!-- agentic-kit:start --> … <!-- agentic-kit:end -->` block in `CLAUDE.md` / `AGENTS.md` / `.gitignore`. `agentic-kit/tools/teardown.sh` either strips the block or removes the file when its SHA-256 still matches the kit copy.
```

- [ ] **Step 4: Delete the "What each `--ide` produces" table**

Remove the table (currently ~41-48) and the heading line above it. Replace with:

```markdown
**What `init.sh` produces:**

- Skills copied to `.claude/skills/`
- Agents copied to `.claude/agents/`
- Pipeline entry-point: managed include block in `CLAUDE.md` and `AGENTS.md`, both pointing to `@.akt/PIPELINE.md`
```

- [ ] **Step 5: Delete the "How to invoke (by IDE)" matrix and the "Mockups vs Cmok build" Cursor sentence**

Remove the table at lines ~98-102 and the paragraph at ~94. Replace with:

```markdown
**How to invoke**

| Kind | Names |
|------|--------|
| Skills | `/vadavik`, `/lojma`, `/laznik`, `/cmok` |
| Agents | `@bagnik`, `@cmok` (build), `@mokash`, `@veles`, `@zlydni` |

The build implementation after Bagnik passes is the `@cmok` agent. The mockup phase uses the `/cmok` skill. They share a name because they share the role; the kit no longer maintains per-IDE shims to disambiguate.
```

- [ ] **Step 6: Strip Cursor/Copilot footnotes**

Remove the "Same roles elsewhere: Cursor — / skill picker…" footnote (currently around line 199). Remove any remaining occurrences of "Cursor" / "Copilot" / "GitHub Copilot" with `grep -n 'Cursor\|Copilot\|copilot' templates/PIPELINE.md.template`. None should remain.

- [ ] **Step 7: Verify**

Run:
```bash
grep -n 'cursor\|copilot\|github\|--ide' templates/PIPELINE.md.template
```

Expected: no matches.

- [ ] **Step 8: Commit**

```bash
git add templates/PIPELINE.md.template
git commit -m "refactor(template): make PIPELINE IDE-agnostic"
```

---

### Task 2: Strip Cursor frontmatter and `cmok-build` from agents and skills

**Files:**
- Modify: `agents/cmok.md` (lines 3-4 hold the `cursor_rule_name: cmok-build` shim)
- Modify: `skills/cmok/SKILL.md` (line ~76 references `/cmok-build`)
- Sweep: every other file under `agents/` and `skills/` for `cursor_rule_name`, `cursor_subagent_name`, `cmok-build`

- [ ] **Step 1: Audit**

Run:
```bash
grep -rn 'cursor_rule_name\|cursor_subagent_name\|cmok-build' agents/ skills/
```

Note the exact list of hits. Currently: `agents/cmok.md:3-4`, `skills/cmok/SKILL.md:76`. If others appear, include them in Step 2.

- [ ] **Step 2: Edit `agents/cmok.md`**

Open the file. Remove lines 3 and 4 (the comment about Cursor subagent stem and the `cursor_rule_name: cmok-build` field). The frontmatter should retain `name:`, `description:`, `model:`, `background:` and any non-IDE keys.

- [ ] **Step 3: Edit `skills/cmok/SKILL.md`**

At the line currently reading `If asked to build, hand off to the **Cmok build agent** (\`@cmok\` in Claude Code / Copilot; **\`/cmok-build\`** subagent in Cursor)`, replace the parenthetical with simply `(\`@cmok\` agent)`:

```markdown
- If asked to build, hand off to the **Cmok build agent** (`@cmok` agent)
```

- [ ] **Step 4: Sweep any remaining hits**

Run the Step 1 grep again. If it still returns matches, edit them out. Apply the same rule: drop `cursor_*` frontmatter, replace `cmok-build` references with `@cmok`, remove "in Cursor:" / "in Copilot:" prose.

- [ ] **Step 5: Verify**

Run:
```bash
grep -rn 'cursor_rule_name\|cursor_subagent_name\|cmok-build\|Cursor\|Copilot' agents/ skills/
```

Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add agents/ skills/
git commit -m "refactor(agents,skills): drop cursor_* frontmatter and cmok-build shim"
```

---

### Task 3: Strip Cursor/Copilot from `README.md`, `autoresearch/run.sh`, and `templates/autoresearch/program.md`

**Files:**
- Modify: `README.md`
- Modify: `autoresearch/run.sh:100,104`
- Modify: `templates/autoresearch/program.md` (only if Cursor/Copilot mentions exist)

- [ ] **Step 1: Audit README.md**

Run:
```bash
grep -n 'cursor\|copilot\|github Copilot\|--ide\|cmok-build' README.md
```

Identify all the lines mentioning per-IDE setup, the IDE matrix table, and the Cmok-build footnote.

- [ ] **Step 2: Rewrite the "Supported IDEs" section in README.md**

Find the section that documents per-IDE install (currently around lines 80-170, multiple blocks). Replace per-IDE setup paragraphs and the bulleted list at line ~159 with:

```markdown
## Supported IDEs

agentic-kit installs **one** Claude-shaped layout (`.claude/agents/`, `.claude/skills/`) and writes two entry-point files at the project root:

- **`CLAUDE.md`** — read natively by Claude Code.
- **`AGENTS.md`** — the cross-IDE convention. Read by Cursor, GitHub Copilot, Codex, and any other workspace-aware tool that follows the `AGENTS.md` spec.

Both files contain the same managed include block pointing at `.akt/PIPELINE.md`. To configure the kit for any supported IDE, run:

`​``bash
agentic-kit/tools/init.sh --non-interactive
`​``

Earlier versions of the kit supported `--ide=cursor` and `--ide=github` flags that generated dedicated `.cursor/` and `.github/` trees. Those flags were removed because the AGENTS.md convention covers the same use cases with one tenth the surface area. If you upgrade an existing project, `update.sh` automatically sweeps the legacy `.cursor/` and `.github/` artefacts (only those the kit installed and you haven't edited).
```

- [ ] **Step 3: Edit the `agents/cmok.md` line in the README invocation table**

At line ~348, the row `| Build | \`@cmok\` · **\`/cmok-build\`** |` becomes `| Build | \`@cmok\` |`. Drop the `/cmok-build` shorthand from any other occurrence in README.md.

- [ ] **Step 4: Verify README**

```bash
grep -n 'cursor\|copilot\|--ide\|cmok-build' README.md
```

Expected: no matches except possibly historical references in CHANGELOG-style sections; if any remain, decide case-by-case whether to keep them as historical record (a recent CHANGELOG entry inside README is fine to keep; live install instructions are not).

- [ ] **Step 5: Edit `autoresearch/run.sh`**

At lines 100 and 104 the loops enumerate both `.claude/agents .cursor/agents` and `.claude/skills .cursor/skills`. Reduce each list to the Claude path only:

```bash
for d in .claude/agents; do
  …
done

for d in .claude/skills; do
  …
done
```

- [ ] **Step 6: Audit `templates/autoresearch/program.md`**

```bash
grep -n 'cursor\|copilot\|--ide' templates/autoresearch/program.md
```

If matches appear, remove the offending sentences (keep the rule about no network mutations / no `gh pr create` — that's a security rule, not an IDE rule).

- [ ] **Step 7: Verify**

```bash
grep -rn 'cursor\|copilot\|--ide\|cmok-build' README.md autoresearch/ templates/autoresearch/
```

Expected: no matches.

- [ ] **Step 8: Commit**

```bash
git add README.md autoresearch/run.sh templates/autoresearch/program.md
git commit -m "refactor(docs,autoresearch): drop Cursor and Copilot references"
```

---

## Phase 2 — Tooling refactor

### Task 4: Lift `teardown_managed_file` / `teardown_managed_tree` into `lib.sh`

**Files:**
- Modify: `tools/lib.sh`
- Modify: `tools/teardown.sh`

**Rationale:** `update.sh` needs the manifest-SHA safety predicate for its legacy sweep. Duplicating the code would diverge. Hoisting the helpers to `lib.sh` lets both files share one implementation.

- [ ] **Step 1: Locate the helpers in `teardown.sh`**

The current definitions live around lines 104-196 (`_manifest_drop`, `teardown_managed_file`, `teardown_managed_tree`). Read them and note any reliance on locals defined in `teardown.sh` (e.g., `DRY_RUN`, `do_rm`, `do_rm_rf`).

- [ ] **Step 2: Decide what moves**

`do_rm` and `do_rm_rf` reference `$DRY_RUN`. Move six functions into `lib.sh`:
- `do_rm` → renamed `kit_rm`
- `do_rm_rf` → renamed `kit_rm_rf`
- `_manifest_drop` (kept as-is, internal)
- `teardown_managed_file` → renamed `kit_managed_file_remove`
- `teardown_managed_tree` → renamed `kit_managed_tree_remove`
- `teardown_include_block` → renamed `kit_include_block_remove`

The renames communicate that these are now library primitives, not teardown-private. They read `DRY_RUN` from the calling script's environment (already the existing behaviour — sourced, not invoked).

- [ ] **Step 3: Add helpers to `lib.sh`**

Append to `tools/lib.sh` (after the existing manifest helpers, before the gitignore block):

```bash
# Dry-run-aware removal helpers. Callers set DRY_RUN=true to preview.
kit_rm() {
  if [ "${DRY_RUN:-false}" = "true" ]; then
    info "would remove: $1"
  else
    rm "$1"
  fi
}

kit_rm_rf() {
  if [ "${DRY_RUN:-false}" = "true" ]; then
    info "would remove: $1"
  else
    rm -rf "$1"
  fi
}

_manifest_drop() {
  if [ "${DRY_RUN:-false}" != "true" ]; then manifest_remove_entry "$1"; fi
}

# Remove a regular file if the manifest hash matches (or legacy kit marker, no manifest).
kit_managed_file_remove() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -f "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a regular file — delete manually)"
    return 1
  fi

  have=$(kit_sha256_file "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && grep -qF "$AGENTIC_MARKER" "$abs" 2>/dev/null; then
    kit_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy kit marker, no manifest)"
    return 0
  fi

  skip "$rel (modified or unknown — hash mismatch or not kit-managed)"
}

# Remove a copied tree if the manifest hash matches (or matches live kit source).
kit_managed_tree_remove() {
  local rel="$1"
  local kit_src="$2"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have want

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    kit_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -d "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a directory — delete manually)"
    return 1
  fi

  have=$(kit_sha256_tree "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    kit_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && [ -d "$kit_src" ]; then
    want=$(kit_sha256_tree "$kit_src") || true
    if [ -n "$want" ] && [ -n "$have" ] && [ "$have" = "$want" ]; then
      kit_rm_rf "$abs"
      _manifest_drop "$rel"
      removed "$rel (matches kit source, no manifest)"
      return 0
    fi
  fi

  skip "$rel (modified locally — hash mismatch)"
}
```

- [ ] **Step 4: Remove originals from `teardown.sh`**

Delete the definitions of `do_rm`, `do_rm_rf`, `_manifest_drop`, `teardown_managed_file`, `teardown_managed_tree` from `tools/teardown.sh` (around lines 89-196).

- [ ] **Step 5: Replace call sites in `teardown.sh`**

Within `teardown.sh`, search-and-replace:
- `teardown_managed_file` → `kit_managed_file_remove`
- `teardown_managed_tree` → `kit_managed_tree_remove`
- `do_rm ` → `kit_rm `
- `do_rm_rf ` → `kit_rm_rf `

Run:
```bash
grep -n 'teardown_managed_file\|teardown_managed_tree\|do_rm\b\|do_rm_rf' tools/teardown.sh
```

Expected: no matches.

- [ ] **Step 6: Lint and sanity-check**

```bash
shellcheck tools/lib.sh tools/teardown.sh
```

Expected: no new findings beyond the existing `.shellcheckrc` exceptions.

Source-check (won't run teardown, just verifies syntax):
```bash
bash -n tools/lib.sh && bash -n tools/teardown.sh && echo OK
```

Expected: `OK`.

- [ ] **Step 7: Commit**

```bash
git add tools/lib.sh tools/teardown.sh
git commit -m "refactor(lib): hoist managed-file/tree teardown helpers into lib.sh"
```

---

### Task 5: Rewrite `tools/init.sh` — drop `--ide`, add `AGENTS.md`, remove Cursor/Copilot generation

**Files:**
- Modify: `tools/init.sh`

**Rationale:** This is the biggest single edit (~250 lines removed, ~10 added). Do it as one commit so init.sh ships internally consistent.

- [ ] **Step 1: Audit**

```bash
grep -n 'cursor\|copilot\|github\|--ide\|IDE_CHOICE' tools/init.sh
```

Note all match groups. Roughly: header comments (lines 3-44), help text (~80-142), arg parsing (~184-201), Cursor helpers (~368-484), include block writer (~489-501, currently IDE-labelled), Cursor skill / subagent install (~530-598), GitHub helpers and install (~602-711), interactive IDE prompt (~793-851, ~896-967), fill-flow (~1035).

- [ ] **Step 2: Edit the header docstring**

Replace lines 3-29 (the usage / overview block) with a version that documents the single install target only:

```bash
# Usage: agentic-kit/tools/init.sh [--force | --overwrite-all | --skip | --skip-all | --non-interactive]
#
# Installs the kit's Claude-shaped layout into a project:
#   1. Creates `.akt/` and copies the canonical pipeline doc + project config:
#         .akt/PIPELINE.md   (kit-managed; refreshed on update)
#         .akt/PROJECT.md    (you edit; kept on update)
#   2. Installs agents (.claude/agents/) and skills (.claude/skills/) from the
#      kit submodule. SHA-256 of every installed file is recorded in
#      .akt/.agentic-kit.files so teardown.sh refuses to delete paths you've
#      edited locally.
#   3. Adds a managed include block to (or creates) CLAUDE.md and AGENTS.md.
#      Block delimiters: <!-- agentic-kit:start --> ... <!-- agentic-kit:end -->
#      The block points at .akt/PIPELINE.md. Existing user content above/below
#      the markers is preserved verbatim.
#   4. Adds a managed block to .gitignore covering ephemeral state under
#      .akt/{memory,features,archive,proposed-patches,scratch}/ plus kit
#      bookkeeping.
#
# Flags:
#   --force, --overwrite-all   Overwrite all existing kit-managed paths without prompting
#   --skip, --skip-all         Skip every existing path without prompting
#   --non-interactive, -n      Agent / CI mode: no prompts, skip existing files, emit
#                              [AGENT ACTION REQUIRED] instruction to fill PROJECT.md
#                              (aliases: --yes, -y)
#
# Cross-IDE support: Cursor, GitHub Copilot, Codex, and other workspace-aware
# tools read AGENTS.md as a universal entry-point. The kit no longer generates
# dedicated .cursor/ or .github/ trees — see CHANGELOG for the migration note.
```

- [ ] **Step 3: Edit the `show_help()` function (~lines 64-145)**

Replace its body (the entire `cat <<'EOF' … EOF` block) so it documents the single install. Remove the `--ide`, `IDE_CHOICE`, per-IDE descriptions, the `.cursor/` and `.github/` lines from the layout tree, and the per-IDE example invocations. The new help text should mention only one install command:

```bash
show_help() {
  cat <<'EOF'

  agentic-kit / init.sh

  Bootstrap agentic-kit in the current project (run from project root).

  USAGE
    agentic-kit/tools/init.sh [--force | --overwrite-all | --skip | --skip-all]
                              [--non-interactive | -n | --yes | -y]
                              [--help | -h]

  WHAT IT DOES
    1. Writes .akt/PIPELINE.md (canonical pipeline) and .akt/PROJECT.md
       (project-specific config; you fill in placeholders).
    2. Copies agents to .claude/agents/ and skills to .claude/skills/.
    3. Adds a managed include block to CLAUDE.md and AGENTS.md, both pointing
       at .akt/PIPELINE.md. Existing user content is preserved verbatim.
    4. Adds a managed block to .gitignore for ephemeral state.

  CROSS-IDE
    Claude Code reads CLAUDE.md natively. Cursor, GitHub Copilot, Codex, and
    other workspace-aware tools read AGENTS.md (the cross-IDE convention).
    One install covers all of them.

  FLAGS
    --force, --overwrite-all   Overwrite all kit-managed paths without prompting.
    --skip, --skip-all         Skip every existing path without prompting.
    --non-interactive, -n      Agent / CI mode (aliases: --yes, -y).
    --help, -h                 Show this help and exit.

  EXAMPLES
    agentic-kit/tools/init.sh                            # interactive
    agentic-kit/tools/init.sh --non-interactive          # CI / agent
EOF
}
```

- [ ] **Step 4: Replace `--ide` argument handling with an explicit rejection**

In the argument-parsing loop (around line 184), change the `--ide=*` case from:
```bash
    --ide=*)                         IDE_CHOICE="${arg#--ide=}" ;;
```
to:
```bash
    --ide=*)
      err "--ide=* was removed in this version; Cursor and Copilot support now goes through AGENTS.md (see CHANGELOG.md). Re-run without --ide=."
      exit 2
      ;;
```

Also delete the line above the loop that reads `IDE_CHOICE` from the environment (search the file for `IDE_CHOICE=` and `IDE_CHOICE:-` — every reference is being removed).

Delete the validation block at lines ~199-201:
```bash
if [ -n "$IDE_CHOICE" ] && [[ ! "$IDE_CHOICE" =~ ^(claude|cursor|github|both|all)$ ]]; then
  err "Invalid --ide value '$IDE_CHOICE' (use claude, cursor, github, all, or both)"
fi
```

- [ ] **Step 5: Delete all Cursor helper functions**

Delete the entire block of functions around lines 368-484:
- `extract_yaml_field` — **keep this if any other function in `init.sh` or `lib.sh` calls it** (run `grep -n extract_yaml_field tools/` to confirm). If unused outside the Cursor helpers, delete it.
- `cursor_subagent_stem`, `cursor_subagent_stem_safe`, `write_cursor_subagent`, `install_or_update_cursor_subagent_file`, `generate_cursor_subagents_from_sources` — delete all five outright.

- [ ] **Step 6: Simplify `install_pipeline_include`**

Around line 489 the function currently takes three arguments (dest path, label, IDE name). The IDE name is used in the embedded comment. Reduce to two arguments (dest path, label). Replace the `# Managed include block — entry-point file (CLAUDE.md / AGENTS.md / copilot-instructions.md)` comment and the IDE label parameter with a fixed string `agentic-kit` in the embedded comment block.

Run:
```bash
grep -n 'install_pipeline_include' tools/init.sh
```

There should now be exactly two call sites (Step 8 below adds the second). Adjust both to use the new two-arg signature.

- [ ] **Step 7: Delete Cursor and GitHub Copilot install paths**

Delete entire functions and their callers:
- `link_cursor_skills` and the `Cursor — Skills` header block (~530-547)
- `setup_cursor_subagents` (~563-566)
- `setup_cursor` (~588-600)
- `write_github_agent` (~604-625)
- `write_github_instructions` (~627-646)
- `setup_github` (~647-711)

Also delete:
- The interactive IDE prompt branches in the prompt loop (~793-797 — the `u|U` and `p|P` choices)
- The dispatcher switch at ~838-851 — the new flow always calls `setup_claude` (or whatever the existing Claude-only function is named). Inspect the file: if there's no `setup_claude` because the previous code inlined Claude install at the top level, leave the top-level Claude install in place and remove only the `case "$IDE_CHOICE" in … esac` wrapper.
- The Cursor / GitHub branches in the fill-PROJECT.md flow (~896-967) — the kit only checks for `claude` CLI now. Drop the `cursor` / `github|all` cases entirely.
- The remaining Cursor mention at ~1035.

- [ ] **Step 8: Add the AGENTS.md include block install**

Find where `install_pipeline_include "CLAUDE.md" "CLAUDE.md"` (or similar) is called for Claude. Immediately below it, add:

```bash
install_pipeline_include "AGENTS.md" "AGENTS.md"
```

So both entry-point files are written by the same Claude install path. Note: if `install_pipeline_include` is called inside a function like `setup_claude_entrypoint`, add the AGENTS.md call there.

- [ ] **Step 9: Verify**

```bash
grep -n 'cursor\|copilot\|github\|--ide\|IDE_CHOICE' tools/init.sh
```

Expected: only the rejection message in `--ide=*` case and the "Cross-IDE" header in help. No live code references.

```bash
bash -n tools/init.sh && echo OK
shellcheck tools/init.sh
```

Both should report no new errors.

- [ ] **Step 10: Smoke-test init in a scratch dir**

```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
mkdir -p agentic-kit
cp -r /d/Repo/agentic-kit/{tools,agents,skills,templates,memory,autoresearch} agentic-kit/
agentic-kit/tools/init.sh --non-interactive
ls -la
ls -la .akt .claude 2>/dev/null
[ -f CLAUDE.md ] && echo "CLAUDE.md: OK" || echo "CLAUDE.md: MISSING"
[ -f AGENTS.md ] && echo "AGENTS.md: OK" || echo "AGENTS.md: MISSING"
[ ! -d .cursor ] && echo ".cursor/: absent (good)" || echo ".cursor/: PRESENT (BAD)"
[ ! -d .github ] && echo ".github/: absent (good)" || echo ".github/: PRESENT (BAD)"
cd - && rm -rf "$TMPDIR"
```

Expected output (all four lines):
```
CLAUDE.md: OK
AGENTS.md: OK
.cursor/: absent (good)
.github/: absent (good)
```

If any line reports a problem, debug before committing.

- [ ] **Step 11: Commit**

```bash
git add tools/init.sh
git commit -m "refactor(init): drop --ide flag and Cursor/Copilot generation"
```

---

### Task 6: Update `tools/teardown.sh` — drop Cursor/Copilot sections, ensure AGENTS.md stripping

**Files:**
- Modify: `tools/teardown.sh`

- [ ] **Step 1: Update the docstring**

The block at the top of `teardown.sh` (lines 1-26) currently enumerates 6 steps including Cursor (step 4 in the old layout) and GitHub Copilot (step 5). Rewrite the order-of-operations block to reflect the new layout:

```bash
# Removes agentic-kit installed copies from the target project.
#
# Order of operations:
#   1. Strip the kit-managed include block from CLAUDE.md and AGENTS.md
#      (existing user content is preserved verbatim; only the marked block is
#      removed). If we created the file from scratch as a stub and it still
#      matches what we created, the file is removed entirely.
#   2. Remove kit-installed agent / skill copies under .claude/ — but only
#      when their SHA-256 still matches the value recorded in
#      .akt/.agentic-kit.files. Files you edited locally are kept.
#   3. Remove the canonical pipeline copy at .akt/PIPELINE.md when its hash
#      still matches; PROJECT.md is kept unless --full-clean.
#   4. Strip the managed block from .gitignore.
#   5. (--remove-submodule) Deinit the agentic-kit submodule.
#   6. (--full-clean) Sweep .akt/scratch/ (ephemeral runtime files),
#      offer to remove .akt/PROJECT.md, and try to remove the .akt/
#      folder itself if nothing user-owned remains.
```

- [ ] **Step 2: Add `AGENTS.md` to the entry-point teardown**

Find the section currently iterating include-block strips (around line 287-292 — three calls to the old `teardown_include_block` function). Replace those three calls with two, using the new `kit_include_block_remove` name from Task 4:

```bash
kit_include_block_remove "CLAUDE.md"
kit_include_block_remove "AGENTS.md"
```

- [ ] **Step 3: Delete the Cursor section**

Remove the entire block at lines 324-363 (`# 4. Remove Cursor skill copies, subagents, legacy rules` through the empty-dir cleanup).

- [ ] **Step 4: Delete the GitHub Copilot section**

Remove the entire block at lines 366-398 (`# 5. Remove GitHub Copilot generated files` through `.github/` empty-dir cleanup).

- [ ] **Step 5: Renumber the remaining sections in the comments**

After deletion, the headers `# 6.`, `# 7.`, `# 8.`, `# 9.` should renumber to `# 4.`, `# 5.`, `# 6.`, `# 7.` to match the new docstring.

- [ ] **Step 6: Add legacy-sweep section for old `.cursor/` and `.github/` paths**

After the new section 2 (the `.claude/` agent/skill removal) and before section 3, add a new section that calls `kit_managed_file_remove` and `kit_managed_tree_remove` on the legacy paths. Only manifest-matching entries are removed (safety inherent to the helper).

Place these calls under a header:
```bash
# ---------------------------------------------------------------------------
# Legacy Cursor / Copilot artefacts (pre-vX.Y installs)
# ---------------------------------------------------------------------------
header "Legacy IDE artefacts (Cursor / Copilot)"

# Cursor agent subagents
if [ -d "$PROJECT_ROOT/.cursor/agents" ]; then
  for f in "$PROJECT_ROOT/.cursor/agents/"*.md; do
    [ -e "$f" ] || continue
    kit_managed_file_remove ".cursor/agents/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    rmdir "$PROJECT_ROOT/.cursor/agents" 2>/dev/null && removed ".cursor/agents/ (empty dir)" || true
  fi
fi

# Cursor skill copies
if [ -d "$PROJECT_ROOT/.cursor/skills" ]; then
  for skill_dir in "$PROJECT_ROOT/.cursor/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    name=$(basename "$skill_dir")
    kit_managed_tree_remove ".cursor/skills/$name" "$SCRIPT_DIR/skills/$name"
  done
  if ! $DRY_RUN; then
    rmdir "$PROJECT_ROOT/.cursor/skills" 2>/dev/null && removed ".cursor/skills/ (empty dir)" || true
  fi
fi

if [ -d "$PROJECT_ROOT/.cursor" ] && ! $DRY_RUN; then
  rmdir "$PROJECT_ROOT/.cursor" 2>/dev/null && removed ".cursor/ (empty dir)" || true
fi

# GitHub Copilot generated files
if [ -d "$PROJECT_ROOT/.github/agents" ]; then
  for f in "$PROJECT_ROOT/.github/agents/"*.agent.md; do
    [ -e "$f" ] || continue
    kit_managed_file_remove ".github/agents/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    rmdir "$PROJECT_ROOT/.github/agents" 2>/dev/null && removed ".github/agents/ (empty dir)" || true
  fi
fi

if [ -d "$PROJECT_ROOT/.github/instructions" ]; then
  for f in "$PROJECT_ROOT/.github/instructions/"*.instructions.md; do
    [ -e "$f" ] || continue
    kit_managed_file_remove ".github/instructions/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    rmdir "$PROJECT_ROOT/.github/instructions" 2>/dev/null && removed ".github/instructions/ (empty dir)" || true
  fi
fi

# .github/copilot-instructions.md managed block (kit_include_block_remove
# handles stub deletion and block stripping the same way as CLAUDE.md / AGENTS.md)
if [ -f "$PROJECT_ROOT/.github/copilot-instructions.md" ]; then
  kit_include_block_remove ".github/copilot-instructions.md"
fi

if [ -d "$PROJECT_ROOT/.github" ] && ! $DRY_RUN; then
  rmdir "$PROJECT_ROOT/.github" 2>/dev/null && removed ".github/ (empty dir)" || true
fi
```

This block makes teardown idempotent on both fresh and legacy projects — fresh projects no-op on the `[ -d ... ]` guards.

- [ ] **Step 7: Sync the docstring**

Add a step `2a` (or renumber to put the legacy sweep between 2 and 3) describing the legacy sweep — keep the docstring honest.

- [ ] **Step 8: Lint and syntax**

```bash
shellcheck tools/teardown.sh
bash -n tools/teardown.sh && echo OK
```

Expected: no new findings; `OK`.

- [ ] **Step 9: Dry-run smoke-test**

```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
mkdir -p agentic-kit
cp -r /d/Repo/agentic-kit/{tools,agents,skills,templates,memory,autoresearch} agentic-kit/
agentic-kit/tools/init.sh --non-interactive
agentic-kit/tools/teardown.sh --dry-run
cd - && rm -rf "$TMPDIR"
```

Expected: `teardown.sh --dry-run` lists `would remove: CLAUDE.md`, `would remove: AGENTS.md`, `would remove: .claude/agents/*.md`, etc., and reports nothing about `.cursor/` or `.github/` (they don't exist in this scratch install). The legacy-sweep block guards (`[ -d "$PROJECT_ROOT/.cursor/agents" ]`) prevent spurious output.

- [ ] **Step 10: Commit**

```bash
git add tools/teardown.sh
git commit -m "refactor(teardown): drop Cursor/Copilot sections, add legacy sweep, install AGENTS.md alongside CLAUDE.md"
```

---

### Task 7: Rewrite `tools/update.sh` — drop `--ide`, add legacy sweep on refresh

**Files:**
- Modify: `tools/update.sh`

- [ ] **Step 1: Audit**

```bash
grep -n 'cursor\|copilot\|github\|--ide\|IDE_CHOICE' tools/update.sh
```

Note any forwarded `--ide` arg handling.

- [ ] **Step 2: Strip `--ide` forwarding**

Open `tools/update.sh`. The current pattern delegates to `init.sh` with a `forward_args` array. Inspect the construction of `forward_args`. If it explicitly accepts `--ide=*`, remove that case. The script currently relies on `init.sh` accepting `--ide`; now that `init.sh` rejects it, `update.sh` users who pass `--ide=*` will get the same explicit error. That's desired behaviour.

- [ ] **Step 3: Update the docstring**

Replace any reference to `--ide=cursor`, `--ide=github`, or `--ide=all` in the comments and help text at the top of `update.sh` with a one-line note: `# This script no longer accepts --ide; the kit installs a single Claude-shaped layout. See CHANGELOG.`

- [ ] **Step 4: Add a legacy-sweep call**

After `init.sh` runs (it does via `exec`, currently the last line), the sweep is already inside `init.sh`'s pipeline refresh — **no it isn't**: `init.sh` itself doesn't sweep, because a fresh install never has legacy paths. The sweep belongs in `update.sh` because update implies "this project ran a prior version of the kit."

Replace the final `exec "$SCRIPT_DIR/tools/init.sh" "${forward_args[@]}"` with:

```bash
# Run the refresh, then sweep legacy IDE artefacts left behind by older kit
# versions. We don't `exec` because we need to run the sweep after init.sh
# returns.
"$SCRIPT_DIR/tools/init.sh" "${forward_args[@]}"
init_exit=$?
if [ $init_exit -ne 0 ]; then
  exit $init_exit
fi

# Legacy IDE sweep — only removes files whose SHA-256 still matches the kit
# manifest. Locally-edited files are preserved with a warning.
header "Legacy IDE sweep (Cursor / Copilot pre-vX.Y artefacts)"
swept=0
skipped=0
for f in "$PROJECT_ROOT/.cursor/agents/"*.md \
         "$PROJECT_ROOT/.cursor/skills/"*/SKILL.md \
         "$PROJECT_ROOT/.github/agents/"*.agent.md \
         "$PROJECT_ROOT/.github/instructions/"*.instructions.md; do
  [ -e "$f" ] || continue
  rel="${f#"$PROJECT_ROOT/"}"
  if kit_managed_file_remove "$rel" >/dev/null 2>&1; then
    swept=$((swept + 1))
  else
    skipped=$((skipped + 1))
  fi
done
if [ -f "$PROJECT_ROOT/.github/copilot-instructions.md" ]; then
  kit_include_block_remove ".github/copilot-instructions.md"
fi
# Prune empty parents
for d in .cursor/agents .cursor/skills .cursor .github/agents .github/instructions .github; do
  [ -d "$PROJECT_ROOT/$d" ] && rmdir "$PROJECT_ROOT/$d" 2>/dev/null && removed "$d (empty dir)" || true
done

info "Legacy IDE sweep: removed $swept files, skipped $skipped (locally modified)."
```

Note: `update.sh` already sources `lib.sh` (verify with `grep -n 'source.*lib' tools/update.sh`). If it does not, add `source "$(cd "$(dirname "$0")" && pwd)/lib.sh"` near the top so the helpers from Task 4 are available.

`kit_include_block_remove` is defined in `lib.sh` after Task 4. If Task 4 was skipped or the rename did not include this function, fix Task 4 before proceeding — `update.sh` cannot strip `.github/copilot-instructions.md` blocks without it.

- [ ] **Step 5: Lint and syntax**

```bash
shellcheck tools/update.sh
bash -n tools/update.sh && echo OK
```

- [ ] **Step 6: Simulated-upgrade smoke test**

```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
mkdir -p agentic-kit
cp -r /d/Repo/agentic-kit/{tools,agents,skills,templates,memory,autoresearch} agentic-kit/

# Pretend this project came from an old kit version: hand-create legacy files
# AND a matching manifest entry so kit_managed_file_remove will accept them.
mkdir -p .akt .cursor/agents .cursor/skills/cmok .github/agents .github/instructions
echo "fake legacy cursor agent" > .cursor/agents/bagnik.md
echo "fake legacy cursor skill" > .cursor/skills/cmok/SKILL.md
echo "fake legacy github agent" > .github/agents/bagnik.agent.md
echo "fake legacy github instructions" > .github/instructions/cmok.instructions.md

# Build the manifest entries
hash_cursor_agent=$(sha256sum .cursor/agents/bagnik.md | awk '{print $1}')
hash_github_agent=$(sha256sum .github/agents/bagnik.agent.md | awk '{print $1}')
hash_github_instr=$(sha256sum .github/instructions/cmok.instructions.md | awk '{print $1}')

cat > .akt/.agentic-kit.files <<EOF
.cursor/agents/bagnik.md	$hash_cursor_agent
.github/agents/bagnik.agent.md	$hash_github_agent
.github/instructions/cmok.instructions.md	$hash_github_instr
EOF
# Note: .cursor/skills/cmok/ is intentionally NOT in the manifest, to test the
# "matches live kit source" fallback path. Hand-build the file to match the
# kit's SKILL.md byte-for-byte.
cp agentic-kit/skills/cmok/SKILL.md .cursor/skills/cmok/SKILL.md

# Also need a minimal PROJECT.md so init doesn't fail
echo "# PROJECT" > .akt/PROJECT.md

# Run update
agentic-kit/tools/update.sh --non-interactive --no-pull 2>&1 | tee /tmp/update.log

# Verify
echo "=== Verification ==="
[ ! -d .cursor ] && echo ".cursor/: removed (good)" || echo ".cursor/: STILL PRESENT (BAD)"
[ ! -d .github ] && echo ".github/: removed (good)" || echo ".github/: STILL PRESENT (BAD)"
grep -F "Legacy IDE sweep:" /tmp/update.log && echo "summary line present (good)" || echo "summary line MISSING (BAD)"

cd - && rm -rf "$TMPDIR"
```

Expected: all three verification lines pass.

- [ ] **Step 7: Local-edit preservation smoke test**

```bash
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
mkdir -p agentic-kit
cp -r /d/Repo/agentic-kit/{tools,agents,skills,templates,memory,autoresearch} agentic-kit/
mkdir -p .akt .cursor/agents
echo "ORIGINAL kit content" > .cursor/agents/bagnik.md
orig_hash=$(sha256sum .cursor/agents/bagnik.md | awk '{print $1}')
mkdir -p .akt
cat > .akt/.agentic-kit.files <<EOF
.cursor/agents/bagnik.md	$orig_hash
EOF
echo "# PROJECT" > .akt/PROJECT.md

# Now edit it locally
echo "USER MODIFIED" > .cursor/agents/bagnik.md

# Run update
agentic-kit/tools/update.sh --non-interactive --no-pull 2>&1 | tee /tmp/update.log

# Verify
[ -f .cursor/agents/bagnik.md ] && [ "$(cat .cursor/agents/bagnik.md)" = "USER MODIFIED" ] \
  && echo "local edit preserved (good)" || echo "local edit LOST (BAD)"
grep -F "skipped" /tmp/update.log && echo "skip reported (good)" || echo "skip NOT reported (BAD)"

cd - && rm -rf "$TMPDIR"
```

Expected: both verification lines pass.

- [ ] **Step 8: Commit**

```bash
git add tools/update.sh tools/lib.sh
git commit -m "refactor(update): drop --ide forwarding, add legacy Cursor/Copilot sweep"
```

(Only `update.sh` should change in this commit; `lib.sh` was finalized in Task 4.)

---

## Phase 3 — Verification

### Task 8: End-to-end fresh-install verification

**Files:**
- Create: `docs/superpowers/plans/2026-05-21-drop-cursor-copilot-verify.sh` (verification harness; deleted after this task)

- [ ] **Step 1: Write the harness**

Write a single bash script that exercises the four spec scenarios end-to-end:
1. Fresh install
2. Simulated upgrade
3. Local-edit preservation
4. Teardown round-trip

```bash
#!/usr/bin/env bash
set -e
KIT=$(pwd)
TMP=$(mktemp -d)
echo "Working in $TMP"

echo "=== Scenario 1: fresh install ==="
mkdir -p "$TMP/s1/agentic-kit"
cp -r "$KIT"/{tools,agents,skills,templates,memory,autoresearch} "$TMP/s1/agentic-kit/"
cd "$TMP/s1"
agentic-kit/tools/init.sh --non-interactive
[ -f CLAUDE.md ] && [ -f AGENTS.md ] && [ -d .claude/agents ] && [ -d .claude/skills ] && [ -d .akt ]
[ ! -d .cursor ] && [ ! -d .github ]
echo "  fresh install: PASS"

echo "=== Scenario 2: simulated upgrade ==="
mkdir -p "$TMP/s2/agentic-kit" "$TMP/s2/.akt" "$TMP/s2/.cursor/agents" "$TMP/s2/.github/agents"
cp -r "$KIT"/{tools,agents,skills,templates,memory,autoresearch} "$TMP/s2/agentic-kit/"
cd "$TMP/s2"
echo "legacy" > .cursor/agents/x.md
h=$(sha256sum .cursor/agents/x.md | awk '{print $1}')
printf '.cursor/agents/x.md\t%s\n' "$h" > .akt/.agentic-kit.files
echo "# PROJECT" > .akt/PROJECT.md
agentic-kit/tools/update.sh --non-interactive --no-pull >/dev/null 2>&1
[ ! -d .cursor ] && echo "  upgrade sweep: PASS" || { echo "  upgrade sweep: FAIL"; exit 1; }

echo "=== Scenario 3: local-edit preservation ==="
mkdir -p "$TMP/s3/agentic-kit" "$TMP/s3/.akt" "$TMP/s3/.cursor/agents"
cp -r "$KIT"/{tools,agents,skills,templates,memory,autoresearch} "$TMP/s3/agentic-kit/"
cd "$TMP/s3"
echo "ORIG" > .cursor/agents/x.md
h=$(sha256sum .cursor/agents/x.md | awk '{print $1}')
printf '.cursor/agents/x.md\t%s\n' "$h" > .akt/.agentic-kit.files
echo "# PROJECT" > .akt/PROJECT.md
echo "EDITED" > .cursor/agents/x.md   # diverge from manifest
agentic-kit/tools/update.sh --non-interactive --no-pull >/dev/null 2>&1 || true
[ -f .cursor/agents/x.md ] && [ "$(cat .cursor/agents/x.md)" = "EDITED" ] \
  && echo "  local-edit preserved: PASS" || { echo "  local-edit preserved: FAIL"; exit 1; }

echo "=== Scenario 4: teardown round-trip ==="
cd "$TMP/s1"
agentic-kit/tools/teardown.sh --yes >/dev/null 2>&1
[ ! -d .claude ] && [ ! -f CLAUDE.md ] && [ ! -f AGENTS.md ] \
  && echo "  teardown: PASS" || { echo "  teardown: FAIL"; exit 1; }

echo "=== All scenarios PASS ==="
rm -rf "$TMP"
```

Save as `docs/superpowers/plans/2026-05-21-drop-cursor-copilot-verify.sh`. Make executable: `chmod +x docs/superpowers/plans/2026-05-21-drop-cursor-copilot-verify.sh`.

- [ ] **Step 2: Run the harness**

From the kit repo root:
```bash
bash docs/superpowers/plans/2026-05-21-drop-cursor-copilot-verify.sh
```

Expected final line: `=== All scenarios PASS ===`. If any scenario fails, the script `exit 1`s — debug the failing task before continuing.

- [ ] **Step 3: Delete the harness**

The harness is one-time; the spec doesn't ask for it to live in the tree.

```bash
rm docs/superpowers/plans/2026-05-21-drop-cursor-copilot-verify.sh
```

- [ ] **Step 4: Run `validate-config.sh` smoke**

```bash
TMP=$(mktemp -d)
mkdir -p "$TMP/agentic-kit"
cp -r tools agents skills templates memory autoresearch "$TMP/agentic-kit/"
cd "$TMP"
agentic-kit/tools/init.sh --non-interactive
# init.sh will print [AGENT ACTION REQUIRED]; placeholders in PROJECT.md remain.
# Validate that the placeholder check still works (it should report unresolved
# placeholders, but should NOT mention --ide / cursor / github / copilot).
agentic-kit/tools/validate-config.sh 2>&1 | tee /tmp/vc.log || true
! grep -i 'cursor\|copilot\|--ide' /tmp/vc.log && echo "validate-config clean: PASS"
cd - && rm -rf "$TMP"
```

Expected: `validate-config clean: PASS`.

- [ ] **Step 5: No commit**

This task produces no tracked file changes (the harness was deleted in Step 3).

---

## Phase 4 — Closure

### Task 9: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add entry under `[Unreleased]`**

Insert a new sub-section into the `[Unreleased]` block (currently starts at line 11). Pick the right semantic-versioning verb — this is **Removed** + **Changed**:

```markdown
### Removed
- **`--ide=` flag** and all Cursor / GitHub Copilot generation. Previously
  `init.sh`, `update.sh`, and `teardown.sh` produced and managed three
  parallel install trees (`.claude/`, `.cursor/`, `.github/`). The kit now
  installs **one** Claude-shaped layout. Cursor, GitHub Copilot, Codex, and
  other workspace-aware tools read `AGENTS.md` — the kit writes it alongside
  `CLAUDE.md` with the same managed include block.
- **`cursor_rule_name` / `cursor_subagent_name`** YAML keys on agent and skill
  files, and the `cmok-build` subagent shim that worked around Cursor's
  namespace clash between the `cmok` skill and `cmok` agent.

### Changed
- `init.sh` now rejects `--ide=*` with an explicit error and exit code 2. CI
  scripts that pass the flag will fail loudly rather than silently install the
  wrong layout.
- `update.sh` automatically sweeps legacy `.cursor/agents/`, `.cursor/skills/`,
  `.github/agents/`, `.github/instructions/`, and the managed block in
  `.github/copilot-instructions.md`. Only files whose SHA-256 still matches the
  kit manifest are removed; locally-edited files are skipped with a warning.
- `tools/lib.sh` gained `kit_managed_file_remove` and `kit_managed_tree_remove`
  (lifted from `teardown.sh`) so `update.sh` and `teardown.sh` share the
  manifest-safety predicate.

### Migration
Run `agentic-kit/tools/update.sh` once. It refreshes the pipeline, agents, and
skills the same way it always has, then sweeps the legacy `.cursor/` and
`.github/` trees. If you edited any of those files locally, they are preserved
with a `[skipped: locally modified]` warning — remove them manually if no
longer needed.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): record drop of Cursor/Copilot support"
```

---

## Final verification (no commit)

- [ ] **Step 1: Global grep**

From the kit repo root:
```bash
grep -rni 'cursor\|copilot\|--ide\|cmok-build' \
  --include='*.sh' --include='*.md' --include='*.template' \
  --exclude-dir='docs/superpowers' \
  --exclude-dir='.specstory' \
  --exclude-dir='.git'
```

Expected: the only matches should be the rejection message in `init.sh`, the CHANGELOG entry, and the README "Cross-IDE" section. **No live code** references Cursor, Copilot, `--ide`, or `cmok-build`.

- [ ] **Step 2: ShellCheck**

```bash
shellcheck tools/*.sh memory/tools/*.sh autoresearch/*.sh autoresearch/tools/*.sh
```

Expected: no new findings.

- [ ] **Step 3: Smoke**

Re-run the verify harness from Task 8 Step 1 once more (don't commit — just confirm green).

If anything is red, fix in the relevant task and amend its commit (or add a fix-up commit). Do not declare done while a smoke test fails.

---

## Self-Review (post-write)

**Spec coverage check:**
- Architecture (single install, CLAUDE.md + AGENTS.md) → Tasks 5, 6
- What disappears (Cursor/Copilot paths, --ide, cursor_* fields, cmok-build) → Tasks 1, 2, 3, 5, 6
- Component changes (every file listed) → Tasks 1–7, 9
- Migration behaviour (sweep, safety, summary) → Task 7
- Backward compatibility (--ide rejection with clear message) → Task 5 Step 4
- Testing strategy (5 scenarios in spec) → Task 8 + Task 5 Step 10 + Task 6 Step 9 + Task 7 Steps 6 & 7

All spec sections are covered by at least one task.

**Placeholder scan:** no `TBD`, `TODO`, or "implement later" tokens. The `vX.Y` placeholder in the rejection message and CHANGELOG is intentional and called out in the spec.

**Type / signature consistency:**
- `kit_managed_file_remove(rel)` and `kit_managed_tree_remove(rel, kit_src)` — signatures consistent across Task 4 (definition), Task 6 (teardown), Task 7 (update).
- `install_pipeline_include(dest, label)` — reduced from 3 args to 2 in Task 5 Step 6; called twice (CLAUDE.md, AGENTS.md) in Task 5 Step 8 with the new signature.
- `kit_include_block_remove` — defined in Task 4 (rename from `teardown_include_block`), called in Task 6 Step 2 and Task 7 Step 4.

Plan is consistent. Proceeding.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-21-drop-cursor-copilot.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
