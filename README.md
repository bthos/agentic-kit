# agentic-kit

A reusable AI development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Works with **Claude Code** (native `.claude/` layout) and **Cursor** (generated `.cursor/rules/*.mdc` + `AGENTS.md`). Import as a git submodule in under a minute.

## What it is

A self-organizing team of AI agents for structured development. Each agent knows its role and who to hand off to next. Quality gates ensure nothing ships without passing Bahnik.

```
Idea → Vadavik (spec) → Lojma (UX) + Veles (docs, parallel)
     → Cmok /skill/ (mockups) → User UAT
     → Laznik (arch + tests) → Bahnik (test gate)
     → Cmok /agent/ (build) + Veles (docs, parallel) → Bahnik (code QA)
     → Zlydni (commit + archive)
```

### Agents

| Agent   | Role                      | Model  |
|---------|---------------------------|--------|
| Bahnik  | Test gate & code QA       | Opus   |
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

`init.sh` asks which IDE to target (**Claude Code**, **Cursor**, or **both**). Non-interactive / CI:

```bash
.agentic-kit/init.sh --ide=claude   # default behavior
.agentic-kit/init.sh --ide=cursor
.agentic-kit/init.sh --ide=both
IDE_CHOICE=cursor .agentic-kit/init.sh --skip
```

Then open `PROJECT.md` and fill in the **Project-Specific Configuration** section:

```markdown
- Test command:   `npm test`
- Build command:  `npm run build`
- Version files:  `package.json, manifest.json`
```

**Claude Code:** start a feature with `/vadavik`.

**Cursor:** agents and skills become `.cursor/rules/*.mdc` (with `description` + `alwaysApply` for Cursor's rule system). `PIPELINE.md.template` is also copied to **`AGENTS.md`** (Cursor reads it natively). A `pipeline.mdc` rule uses `alwaysApply: true` so the handoff protocol is always in context. Cmok is split into `cmok-build.mdc` and `cmok-mockups.mdc`. Cursor has no slash commands — the agent picks rules by relevance, or you `@`-mention a rule file.

That's it.

## What `init.sh` does

**Always (all IDE modes):**

1. Creates a `tools/` symlink at your project root → submodule `tools/` (version bumping, validate-config, etc.)
2. Copies `PROJECT.md.template` → `PROJECT.md` if none exists. On a TTY, optionally fills placeholders via the CLI that matches `--ide`: **`claude -p`** (Claude Code) for `claude`, **`agent -p --force`** ([Cursor Agent CLI](https://cursor.com/docs/cli/overview)) for `cursor`. For `both`, it prefers `claude` if installed, otherwise `agent`.
3. Appends `.artefacts/` to `.gitignore` if missing

**Claude Code (`claude` or `both`):**

4. Symlinks `agents/*.md` → `.claude/agents/`
5. Symlinks `skills/*/` → `.claude/skills/`
6. Copies `PIPELINE.md.template` → `CLAUDE.md` if none exists

**Cursor (`cursor` or `both`):**

7. Symlinks `skills/*/` → `.claude/skills/` (Cursor-only mode only — so paths like `.claude/skills/vadavik/new-feature.sh` in skill docs still work)
8. Generates `.cursor/rules/*.mdc` from agents and skills (copies, not symlinks — **re-run `init.sh` after `git submodule update`** to refresh rules)
9. Writes `pipeline.mdc` (`alwaysApply: true`) from `PIPELINE.md.template` (minus the `@PROJECT.md` line)
10. Copies `PIPELINE.md.template` → `AGENTS.md` with a kit-managed marker (for teardown)

The script is **idempotent** — existing kit-managed files prompt for overwrite; use `--force` or `--skip` for non-interactive runs.

## Updating the kit

```bash
# Pull the latest kit version
git submodule update --remote .agentic-kit

# Pick up any newly added agents, skills, or tools
.agentic-kit/init.sh

# Commit the updated submodule pointer so the team gets the same version
git add .agentic-kit
git commit -m "chore: update agentic-kit"
```

**What updates automatically:**
- New agents and skills — `init.sh` creates missing symlinks; existing symlinks are untouched
- `tools/` — already a symlink into the submodule, so tool scripts update with it

**Cursor:** `.cursor/rules/*.mdc` are generated copies — after updating the submodule, run `init.sh` again (same `--ide=` as before) to regenerate rules from the new kit sources.

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
rm .claude/agents/bahnik.md
cp .agentic-kit/agents/bahnik.md .claude/agents/bahnik.md
# Edit .claude/agents/bahnik.md to your needs
```

`init.sh` skips files that already exist, so your override persists across updates.

## Removing the kit

```bash
# Remove Claude symlinks, Cursor kit-managed rules, AGENTS.md, tools/, clean .gitignore
.agentic-kit/teardown.sh

# Or remove the above AND the submodule in one step
.agentic-kit/teardown.sh --remove-submodule
```

`teardown.sh` removes only `.cursor/rules/*.mdc` and `AGENTS.md` files that contain the kit marker (`<!-- agentic-kit managed -->`). Local rules you added yourself are left alone.

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
| Run test gate or code QA | `@bahnik` |
| Build | `@cmok` |
| Write docs | `@veles` |
| Commit | `@zlydni` |

## Scripts

Each skill bundles its own script. Shared scripts live in `tools/`. All scripts run from the project root.

### Skill scripts (bundled, symlinked automatically)

| Script | Invoked by | What it does |
|--------|-----------|--------------|
| `.claude/skills/vadavik/new-feature.sh <slug>` | Vadavik | Creates `.artefacts/features/YYYY-MM-DD-<slug>/` with `spec.md` skeleton and `handoff-log.md` |
| `.claude/skills/laznik/check-coverage.sh [feature-path]` | Laznik | Runs test command, prints results, appends coverage entry to `handoff-log.md` |

### Shared tools

| Script | What it does |
|--------|-------------|
| `tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `PROJECT.md` (Cmok uses `patch`, Zlydni uses `minor`) |
| `tools/validate-config.sh` | Checks `PROJECT.md` for unfilled `<placeholder>` values — run after `init.sh` |
| `tools/feature-status.sh` | Shows pipeline status for active features in `.artefacts/features/` |

### Lifecycle scripts

| Script | What it does |
|--------|-------------|
| `init.sh` | IDE choice: Claude Code, Cursor, or both; symlinks / generates rules; copies `CLAUDE.md` / `AGENTS.md` / `PROJECT.md`; updates `.gitignore` |
| `teardown.sh` | Removes `.claude/` symlinks, kit-managed `.cursor/rules/*.mdc`, kit-managed `AGENTS.md`, `tools/` symlink, `.gitignore` entries; `--remove-submodule` deinits git |

## Handoff protocol

See `CLAUDE.md` or `AGENTS.md` (Handoff Protocol section) for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference so the whole team shares the same pipeline version:

```bash
git add .agentic-kit .gitmodules
git commit -m "chore: add agentic-kit submodule"
```

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
