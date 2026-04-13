# Agentic Kit

A reusable AI development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Works with **Claude Code** (native `.claude/` layout), **Cursor** (symlinked `.cursor/skills/`, generated `.cursor/rules/*.mdc` for agents + `AGENTS.md`), and **GitHub Copilot** (generated `.github/agents/*.agent.md` + `.github/instructions/*.instructions.md`). 

Import as a git submodule in under a minute.

## What it is

A self-organizing team of AI agents for structured development. Each agent knows its role and who to hand off to next. Quality gates ensure nothing ships without passing Bagnik.

```
Idea → Vadavik (spec) → Lojma (UX) + Veles (docs, parallel)
     → Cmok /skill/ (mockups) → User UAT
     → Laznik (arch + tests) → Bagnik (test gate)
     → Cmok /agent/ (build) + Veles (docs, parallel) → Bagnik (code QA)
     → Zlydni (commit + archive)
```

### Agents

| Agent   | Role                      | Model  |
|---------|---------------------------|--------|
| Bagnik  | Test gate & code QA       | Opus   |
| Cmok    | Build                     | Sonnet |
| Veles  | Documentation             | Sonnet |
| Zlydni  | Commits & version control | Haiku  |

### Skills

| Skill    | Role                         |
|----------|------------------------------|
| Vadavik  | Spec & requirements          |
| Lojma    | UX design                    |
| Cmok     | UX mockups                   |
| Laznik   | Architecture & tests         |

## Quick start

```bash
cd your-project
git submodule add https://github.com/bthos/agentic-kit .agentic-kit
.agentic-kit/init.sh
```

`init.sh` asks which IDE to target (**Claude Code**, **Cursor**, **GitHub Copilot**, or **all**). Non-interactive / CI:

```bash
.agentic-kit/init.sh --ide=claude    # default behavior
.agentic-kit/init.sh --ide=cursor
.agentic-kit/init.sh --ide=github
.agentic-kit/init.sh --ide=all       # all three  (alias: --ide=both)

# Agent / CI — no prompts at all:
.agentic-kit/init.sh --non-interactive                  # claude (default)
.agentic-kit/init.sh --non-interactive --ide=github
.agentic-kit/init.sh -n --ide=all                       # short alias

# Other non-interactive bulk choices:
.agentic-kit/init.sh --skip-all       # keep all existing kit paths, no prompts
.agentic-kit/init.sh --overwrite-all  # replace all kit-managed files, no prompts
```

When a path already exists, the interactive prompt is: **s**kip this file, **o**verwrite this file, overwrite **a**ll remaining, or skip **r**est (this file and every later conflict).

`--non-interactive` / `-n` is the recommended flag for agents and CI (aliases: `--yes`, `-y`): it skips existing files, suppresses all Y/n prompts, and prints a structured **`[AGENT ACTION REQUIRED]`** block instructing the calling agent to fill `PROJECT.md` itself — no nested CLI process is spawned. The agent reads the script output and uses its own tools (Read / Glob / Edit) to replace the placeholders.

Then open `PROJECT.md` and fill in the **Project-Specific Configuration** section:

```markdown
- Test command:   `npm test`
- Build command:  `npm run build`
- Version files:  `package.json, manifest.json`
```

**Claude Code:** start a feature with `/vadavik`.

**Cursor:** each kit skill is symlinked to **`.cursor/skills/<name>/`** (with `SKILL.md` and bundled scripts) so [Cursor Agent Skills](https://cursor.com/docs/context/skills) pick them up. Agents become **`.cursor/rules/*.mdc`**. `PIPELINE.md.template` is copied to **`AGENTS.md`**. A `pipeline.mdc` rule uses `alwaysApply: true` so the handoff protocol is always in context. Invoke skills from chat with **`/<skill-name>`** or attach them as context; use **`@`** for rules files.

**GitHub Copilot:** each agent becomes a `.github/agents/<name>.agent.md` custom agent (VS Code Copilot picks these up automatically). Each skill becomes a `.github/instructions/<name>.instructions.md` with `applyTo: '**'` so it applies to every chat. `PIPELINE.md.template` becomes `.github/copilot-instructions.md` — the workspace-wide instructions file Copilot always reads. Use `@<agentname>` in Copilot Chat to invoke a specific agent.

That's it.

## What `init.sh` does

**Always (all IDE modes):**

1. Copies `PROJECT.md.template` → `PROJECT.md` if none exists, or when you choose to overwrite an existing `PROJECT.md`. After any fresh copy from the template, optionally fills placeholders via the CLI that matches `--ide`: **`claude -p`** (Claude Code) for `claude`, **`agent -p --force`** ([Cursor Agent CLI](https://cursor.com/docs/cli/overview)) for `cursor`. Use the **`agent`** binary from [Cursor CLI install](https://cursor.com/docs/cli/installation) — the GUI **`cursor`** launcher is Electron-based and is not used here (passing `-p` to it triggers Chromium “unknown option” warnings). For `all` / `github`, it prefers `claude` if installed, otherwise `agent`. If stdin is not a TTY but `/dev/tty` exists, the Y/n prompt is read from `/dev/tty` so the step is not skipped silently in some IDE terminals.
2. Appends `.artefacts/` to `.gitignore` if missing

Shared scripts live only under **`.agentic-kit/tools/`** — run them from the **project root**, for example `.agentic-kit/tools/validate-config.sh`.

**Claude Code (`claude` or `all`):**

3. Symlinks `agents/*.md` → `.claude/agents/`
4. Symlinks `skills/*/` → `.claude/skills/`
5. Copies `PIPELINE.md.template` → `CLAUDE.md` if none exists

**Cursor (`cursor` or `all`):**

6. Symlinks `skills/*/` → `.claude/skills/` (Cursor-only mode only — so paths like `.claude/skills/vadavik/new-feature.sh` in skill docs still work)
7. Symlinks `skills/*/` → `.cursor/skills/` (same relative layout as the kit — **re-run `init.sh` after `git submodule update`** to refresh)
8. Generates `.cursor/rules/*.mdc` from **agents only** (copies, not symlinks). Optional YAML frontmatter `cursor_rule_name` overrides the basename (e.g. Cmok agent uses `cmok-build.mdc`).
9. Writes `pipeline.mdc` (`alwaysApply: true`) from `PIPELINE.md.template` (minus the `@PROJECT.md` line)
10. Copies `PIPELINE.md.template` → `AGENTS.md` with a kit-managed marker (for teardown)

**GitHub Copilot (`github` or `all`):**

11. Symlinks `skills/*/` → `.claude/skills/` (Copilot-only mode only — for bundled shell scripts)
12. Generates `.github/agents/<name>.agent.md` from each agent (copies, not symlinks — **re-run `init.sh` after `git submodule update`** to refresh). Strips Claude-specific fields; adds standard Copilot `tools` list.
13. Generates `.github/instructions/<name>.instructions.md` from each skill with `applyTo: '**'`
14. Writes `.github/copilot-instructions.md` from `PIPELINE.md.template` (minus the `@PROJECT.md` line) with a kit-managed marker

The script is **idempotent** — existing kit-managed files prompt for overwrite (or **s** / **o** / **a** / **r** as above). For CI or scripts, use **`--force`** / **`--overwrite-all`** or **`--skip`** / **`--skip-all`** so nothing blocks on prompts.

## Updating the kit

One command (pulls the submodule’s **remote** tracking branch, then runs `init.sh` with your usual flags):

```bash
.agentic-kit/update.sh --ide=cursor --skip          # example: match how you first ran init
.agentic-kit/update.sh --non-interactive --ide=all
.agentic-kit/update.sh --no-pull --ide=github --skip   # submodule already updated; only re-run init
```

Equivalent manual steps:

```bash
git submodule update --remote .agentic-kit
.agentic-kit/init.sh   # same --ide= / --skip / etc. as before

git add .agentic-kit
git commit -m "chore: update agentic-kit"
```

**What updates automatically:**
- New agents and skills — `init.sh` creates missing symlinks; existing symlinks are untouched
- Scripts under `.agentic-kit/tools/` — they ship with the submodule; `git submodule update` brings new versions

**Cursor:** `.cursor/skills/` symlinks and `.cursor/rules/*.mdc` copies — after updating the submodule, run `init.sh` again (same `--ide=` as before) to refresh them from the new kit sources.

**GitHub Copilot:** same as Cursor — `.github/agents/*.agent.md` and `.github/instructions/*.instructions.md` are generated copies; re-run `init.sh --ide=github` (or `--ide=all`) after `git submodule update`.

**What does NOT update automatically:**
- `CLAUDE.md` — your project's copy is never overwritten. To pick up protocol changes, diff it against the new template:
  ```bash
  diff CLAUDE.md .agentic-kit/PIPELINE.md.template
  ```
- `AGENTS.md` — same as `CLAUDE.md` for Cursor users; re-copy from template manually or delete and re-run `init.sh --ide=cursor`
- `PROJECT.md` — project-specific config, never touched
- Any agent/skill you replaced with a local file (override) — `init.sh` skips non-symlink files

**Team members:** after pulling, run `git submodule update --init` to sync the submodule to the committed version (no `--remote` needed — that's only for the person pulling the new release).

## Overriding an agent or skill

To customize an agent for your project, replace its symlink with a local file:

```bash
rm .claude/agents/bagnik.md
cp .agentic-kit/agents/bagnik.md .claude/agents/bagnik.md
# Edit .claude/agents/bagnik.md to your needs
```

`init.sh` skips files that already exist, so your override persists across updates.

For **Cursor** skills, `.cursor/skills/<name>` is a symlink to the kit; replace it with a real directory (copy the kit folder and edit) if you need a project-local override — `init.sh` will then skip that path.

## Removing the kit

```bash
# Remove Claude symlinks, Cursor kit-managed rules, AGENTS.md, clean .gitignore
.agentic-kit/teardown.sh

# Or remove the above AND the submodule in one step
.agentic-kit/teardown.sh --remove-submodule
```

`teardown.sh` removes kit skill symlinks under `.cursor/skills/`, then only files that contain the kit marker (`<!-- agentic-kit managed -->`): `.cursor/rules/*.mdc`, `AGENTS.md`, `.github/agents/*.agent.md`, `.github/instructions/*.instructions.md`, `.github/copilot-instructions.md`. Files you added yourself are left alone.

## Feature artifacts

All feature work lives under `.artefacts/`:

```
.artefacts/
├── features/
│   └── YYYY-MM-DD-feature-name/   ← active feature (spec, UX, tech plan, handoffs)
└── archive/
    └── YYYY-MM-DD-feature-name/   ← completed features (moved by Zlydni after commit)
```

Vadavik creates the feature folder automatically when starting a new spec.

## Invocation reference

| What | How |
|------|-----|
| Write or update spec | `/vadavik` |
| Design UX | `/lojma` |
| Create UX mockups | `/cmok` |
| Architecture & tests | `/laznik` |
| Run test gate or code QA | `@bagnik` |
| Build | `@cmok` |
| Write docs | `@veles` |
| Commit | `@zlydni` |

## Scripts

Each skill bundles its own script. Shared scripts live in `.agentic-kit/tools/`. Run them from the **project root** so paths like `PROJECT.md` and `.artefacts/` resolve correctly.

### Skill scripts (bundled, symlinked automatically)

| Script | Invoked by | What it does |
|--------|-----------|--------------|
| `.claude/skills/vadavik/new-feature.sh <slug>` | Vadavik | Creates `.artefacts/features/YYYY-MM-DD-<slug>/` with `spec.md` skeleton and `handoff-log.md` |
| `.claude/skills/laznik/check-coverage.sh [feature-path]` | Laznik | Runs test command, prints results, appends coverage entry to `handoff-log.md` |

### Shared tools

| Script | What it does |
|--------|-------------|
| `.agentic-kit/tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `PROJECT.md` (Cmok uses `patch`, Zlydni uses `minor`) — run from project root |
| `.agentic-kit/tools/validate-config.sh` | Checks `PROJECT.md` for unfilled `<placeholder>` values — run after `init.sh` |
| `.agentic-kit/tools/feature-status.sh` | Shows pipeline status for active features in `.artefacts/features/` |

### Lifecycle scripts

| Script | What it does |
|--------|-------------|
| `lib.sh` | Shared helpers (colors, paths, `AGENTIC_MARKER`) — sourced by `init.sh`, `update.sh`, and `teardown.sh`, not run directly |
| `update.sh` | `git submodule update --remote` for the kit, then `exec` into `init.sh` with the same arguments you pass (optional `--no-pull` to skip the fetch) |
| `init.sh` | IDE choice: Claude Code, Cursor, Copilot, or all; symlinks / generates rules; copies `CLAUDE.md` / `AGENTS.md` / `PROJECT.md`; updates `.gitignore` |
| `teardown.sh` | Removes `.claude/` symlinks, `.cursor/skills/` kit symlinks, kit-managed `.cursor/rules/*.mdc`, `AGENTS.md`, `.github/agents/*.agent.md`, `.github/instructions/*.instructions.md`, `.github/copilot-instructions.md`, `.gitignore` entries; `--remove-submodule` deinits git |

## Handoff protocol

See `CLAUDE.md` or `AGENTS.md` (Handoff Protocol section) for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference so the whole team shares the same pipeline version:

```bash
git add .agentic-kit .gitmodules
git commit -m "chore: add agentic-kit submodule"
```

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
