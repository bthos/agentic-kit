# agentic-kit

A reusable Claude Code development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Import into any project as a git submodule in under a minute.

## What it is

A self-organizing team of AI agents for structured development. Each agent knows its role and who to hand off to next. Quality gates ensure nothing ships without passing Bahnik.

```
Idea → Vadavik (spec) → Lojma (UX) + Piarun (docs, parallel)
     → Cmok /skill/ (mockups) → User UAT
     → Laznik (arch + tests) → Bahnik (test gate)
     → Cmok /agent/ (build) + Piarun (docs, parallel) → Bahnik (code QA)
     → Zlydni (commit + archive)
```

### Agents

| Agent   | Role                      | Model  |
|---------|---------------------------|--------|
| Bahnik  | Test gate & code QA       | Opus   |
| Cmok    | Build                     | Sonnet |
| Piarun  | Documentation             | Sonnet |
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
git submodule add <repo-url> .agentic-kit
.agentic-kit/init.sh
```

Then open `CLAUDE.md` and fill in the **Project-Specific Configuration** section:

```markdown
- Test command:   `npm test`
- Build command:  `npm run build`
- Version files:  `package.json, manifest.json`
```

That's it. Start your first feature with `/vadavik` in Claude Code.

## What `init.sh` does

1. Creates `.claude/agents/` and `.claude/skills/` in your project root
2. Creates **relative symlinks** from those directories into the submodule (portable across machines)
3. Copies `CLAUDE.md.template` → `CLAUDE.md` if none exists (so you can customize it)
4. Appends `.agentic-kit` and `.artefacts/` to your `.gitignore` if not already present

The script is **idempotent** — running it again skips files that already exist.

## Updating the kit

```bash
git submodule update --remote .agentic-kit
.agentic-kit/init.sh
```

New agents and skills are symlinked in automatically. Existing symlinks are untouched.

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
| Write docs | `@piarun` |
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
| `tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `CLAUDE.md` (Cmok uses `patch`, Zlydni uses `minor`) |
| `tools/validate-config.sh` | Checks `CLAUDE.md` for unfilled `<placeholder>` values — run after `init.sh` |
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
