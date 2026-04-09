# agentic-kit

A reusable Claude Code development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Import into any project as a git submodule in under a minute.

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

Then open `PROJECT.md` and fill in the **Project-Specific Configuration** section:

```markdown
- Test command:   `npm test`
- Build command:  `npm run build`
- Version files:  `package.json, manifest.json`
```

That's it. Start your first feature with `/vadavik` in Claude Code.

## What `init.sh` does

1. Creates `.claude/agents/` and `.claude/skills/` in your project root
2. Creates **relative symlinks** from those directories into the submodule (portable across machines)
3. Creates a `tools/` symlink at your project root pointing to the submodule's `tools/` (used by `@cmok` and `@zlydni` for version bumping)
4. Copies `CLAUDE.md.template` → `CLAUDE.md` (pipeline docs, kit-owned) if none exists
5. Copies `PROJECT.md.template` → `PROJECT.md` (your project config) if none exists
6. Appends `.artefacts/` to your `.gitignore` if not already present

The script is **idempotent** — running it again skips files that already exist.

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

**What does NOT update automatically:**
- `CLAUDE.md` — your project's copy is never overwritten. To pick up protocol changes, diff it against the new template:
  ```bash
  diff CLAUDE.md .agentic-kit/CLAUDE.md.template
  ```
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
# Remove symlinks and clean .gitignore
.agentic-kit/teardown.sh

# Or remove symlinks AND the submodule in one step
.agentic-kit/teardown.sh --remove-submodule
```

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
| `init.sh` | Sets up symlinks, copies `CLAUDE.md`, updates `.gitignore` |
| `teardown.sh` | Removes symlinks, cleans `.gitignore`; add `--remove-submodule` to also deinit git |

## Handoff protocol

See `CLAUDE.md` (Handoff Protocol section) for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference so the whole team shares the same pipeline version:

```bash
git add .agentic-kit .gitmodules
git commit -m "chore: add agentic-kit submodule"
```

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
