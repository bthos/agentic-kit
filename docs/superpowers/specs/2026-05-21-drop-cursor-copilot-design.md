# Drop Cursor and Copilot support — single Claude-shaped install

**Date:** 2026-05-21
**Status:** Approved, pending implementation plan
**Scope:** agentic-kit refactor — remove all IDE-specific generation paths, install one structure, rely on cross-IDE `AGENTS.md` as the universal entry-point.

## Motivation

The kit currently maintains three parallel install targets — `.claude/` (Claude Code), `.cursor/` (Cursor), and `.github/` (Copilot) — selected by the `--ide=` flag. Cursor and GitHub Copilot both consume `AGENTS.md` as a workspace entry-point and can resolve the kit's Claude-shaped layout indirectly through it. The per-IDE generation paths therefore add surface area without delivering capability: they triple the number of templates to maintain, complicate teardown, and force every agent/skill author to think about three invocation conventions instead of one.

This refactor collapses the kit to a single install target.

## Architecture

### What the kit installs

| Path | Purpose |
|------|---------|
| `.claude/agents/*.md` | Agent files, copied verbatim from the kit's `agents/`. |
| `.claude/skills/<skill>/` | Skill trees, copied verbatim from the kit's `skills/`. |
| `.akt/PIPELINE.md` | Canonical pipeline doc (kit-managed, refreshed on init/update). |
| `.akt/PROJECT.md` | Project-specific configuration (user-edited, preserved on update). |
| `CLAUDE.md` | Entry-point file with a managed include block pointing at `.akt/PIPELINE.md`. |
| `AGENTS.md` | Same managed include block as `CLAUDE.md`. Read by Cursor, Copilot, Codex, and any other IDE that follows the AGENTS.md convention. |
| `.gitignore` | Managed block ignoring `.akt/{memory,features,archive,proposed-patches,scratch}/`, plus kit bookkeeping. |

### What disappears

- `.cursor/agents/*.md`, `.cursor/skills/`, `.cursor/rules/` (legacy)
- `.github/agents/*.agent.md`, `.github/instructions/*.instructions.md`, `.github/copilot-instructions.md` managed block
- The `--ide=` flag on `init.sh` and `update.sh`
- All per-IDE invocation matrices and "in Cursor:" / "in Copilot:" prose in `PIPELINE.md` and agent/skill files
- `cursor_rule_name` and `cursor_subagent_name` frontmatter keys in `agents/*.md` and `skills/*/SKILL.md`
- The `cmok-build` subagent shim (workaround for Cursor's namespace clash between the `cmok` skill and `cmok` agent)

## Component changes

### `tools/init.sh`

- Drop `--ide=` argument parsing and the IDE dispatch switch.
- Remove generation of Cursor subagent files (`.cursor/agents/*.md`), Cursor skill copies (`.cursor/skills/<skill>/`), and any legacy Cursor rule conversion.
- Remove generation of Copilot agent files (`.github/agents/*.agent.md`) and instruction files (`.github/instructions/*.instructions.md`).
- Remove the managed include block in `.github/copilot-instructions.md`.
- Add `AGENTS.md` to the entry-point install path alongside `CLAUDE.md` — same managed block, same target (`.akt/PIPELINE.md`).
- Reject `--ide=*` with an explicit error: `unknown flag --ide=*; Cursor and Copilot support was removed in v<X.Y>, see CHANGELOG.md`.

### `tools/teardown.sh`

- Drop section 4 (Cursor) and section 5 (GitHub Copilot) entirely.
- Section 1 (entry-point blocks) now strips three files: `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md` — the third only for legacy installs, to clean up after a prior `.github/` install.
- No new flags.

### `tools/update.sh`

- Drop `--ide=` forwarding.
- After the normal refresh of pipeline + agents + skills, run a **legacy sweep**:
  1. For each path the kit previously installed under `.cursor/agents/`, `.cursor/skills/`, `.github/agents/`, `.github/instructions/`: if the file's recorded SHA-256 in `.akt/.agentic-kit.files` still matches the on-disk file, delete the file and drop the manifest entry. If the file has been edited locally, skip it with a `[skipped: locally modified — remove manually]` warning.
  2. Strip the managed block from `.github/copilot-instructions.md` if present; remove the file if it's a kit-created stub.
  3. Remove now-empty parent directories (`.cursor/agents/`, `.cursor/skills/`, `.cursor/`, `.github/agents/`, `.github/instructions/`) using the existing `rmdir`-if-empty pattern.
  4. Print a summary line: `Legacy IDE sweep: removed N files, skipped M (locally modified).`
- The safety predicate (manifest SHA match) re-uses `teardown_managed_file` and `teardown_managed_tree`. **Refactor:** lift those two helpers from `tools/teardown.sh` into `tools/lib.sh` so `update.sh` can call them without code duplication.

### `tools/lib.sh`

- Drop helpers that only existed for Cursor/Copilot output (e.g., Cursor subagent block markers, Copilot instruction frontmatter writers).
- Receive `teardown_managed_file` and `teardown_managed_tree` from `teardown.sh` (refactored).
- The managed `.gitignore` block stays as today (already updated to include `scratch/`).

### `templates/PIPELINE.md.template`

- Remove the "What each `--ide` produces" table.
- Remove the "How to invoke (by IDE)" matrix.
- Collapse "Kit Setup (for agents)" to a single command: `agentic-kit/tools/init.sh --non-interactive`.
- Replace all per-IDE invocation prose with IDE-agnostic phrasing (e.g., "invoke `/cmok`" — no per-IDE column).
- Keep "Shell command conventions" (added in this branch).
- Update the layout diagram: drop `.cursor/` and `.github/` from the tree, keep `.claude/` and `AGENTS.md`.

### `agents/*.md` and `skills/*/SKILL.md`

- Strip `cursor_rule_name` and `cursor_subagent_name` from frontmatter.
- Remove all "in Cursor:" / "in Copilot:" prose.
- Remove `cmok-build` references everywhere; the build agent is just `@cmok` again.

### Other files

- `README.md` — rewrite the "Supported IDEs" section to state: "Claude Code, plus any IDE that reads `AGENTS.md` (Cursor, GitHub Copilot, Codex, etc.)." Drop per-IDE setup steps.
- `CHANGELOG.md` — add an entry under the next version: *"BREAKING: removed `--ide=` flag and dedicated Cursor / Copilot generation. The kit now installs one Claude-shaped layout plus an `AGENTS.md` entry-point. Existing `.cursor/` and `.github/` artefacts are swept on next `update.sh` (only when SHA matches the kit manifest)."*
- `autoresearch/run.sh`, `templates/autoresearch/program.md` — drop any Cursor/Copilot conditional branches or prose; reference only `.claude/agents/` paths.
- `agentic-kit.sh` — verified clean already; no changes expected.

## Migration behaviour

When an existing project (installed with a prior kit version) runs `agentic-kit/tools/update.sh`:

1. Pipeline, agents, skills refresh as today.
2. Legacy sweep removes manifest-matching Cursor and Copilot files.
3. Locally-edited legacy files are preserved with a clear warning.
4. Empty parent dirs are pruned.
5. Summary printed at the end.

A user who wants nothing of the kit to remain runs `agentic-kit/tools/teardown.sh --full-clean` afterward, which already handles `.claude/` and `.akt/` cleanly.

## Backward compatibility

- `--ide=*` is **rejected**, not silently accepted. CI scripts and shell history that still pass it will fail loudly with a message pointing at the CHANGELOG. This is preferred over silent behaviour change.
- A **minor version bump** at minimum; the kit's version policy may justify a major bump given the surface change. Decision deferred to commit time.

## Testing strategy

1. **Fresh install in a scratch dir** — run `init.sh --non-interactive`, verify only `.claude/`, `.akt/`, `CLAUDE.md`, `AGENTS.md`, and the `.gitignore` block appear. No `.cursor/`, no `.github/`.
2. **Simulated upgrade** — create a scratch dir, hand-craft `.cursor/agents/foo.md`, `.cursor/skills/bar/SKILL.md`, `.github/agents/baz.agent.md`, `.github/copilot-instructions.md`, and a matching `.akt/.agentic-kit.files` manifest with their SHA-256 entries. Run `update.sh`. Verify: manifest-matching files removed, manifest entries dropped, empty dirs pruned, summary line printed.
3. **Local-edit preservation** — same as (2), but edit one of the legacy files first. Verify `update.sh` skips it with the warning and keeps the file.
4. **Teardown after upgrade** — run `teardown.sh` then `teardown.sh --full-clean`. Verify nothing complains about missing Cursor/Copilot paths.
5. **`agentic-kit/tools/validate-config.sh`** — passes on the post-refactor template.
6. **Manual smoke** — open the post-install `AGENTS.md` in Cursor; verify the kit's pipeline is discovered. Repeat for Copilot.

## Out of scope

- Adding new IDEs.
- Re-deriving the agent / skill set.
- Changing the `.akt/` directory layout.
- Changing the AGENTS.md spec itself (we follow the existing convention).

## Open questions

None — all design decisions resolved in the brainstorming session on 2026-05-21.
