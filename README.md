# Agentic Kit

A reusable AI development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Works with **Claude Code** (native `.claude/` layout), **Cursor** (copied `.cursor/skills/`, generated [`.cursor/agents/*.md` subagents](https://cursor.com/docs/context/subagents) + `AGENTS.md`), and **GitHub Copilot** (generated `.github/agents/*.agent.md` + `.github/instructions/*.instructions.md`). Installed kit paths are **copies**, not symlinks; **`teardown.sh`** removes each managed file only if its SHA-256 still matches the value recorded in **`.agentic-kit.files`** (so manual edits are preserved). 

Import as a git submodule in under a minute.

## What it is

A self-organizing team of AI agents for structured development. Each agent knows its role and who to hand off to next. Quality gates ensure nothing ships without passing Bagnik.

```
Idea → Vadavik (spec) → Lojma (UX) + Mokash (docs, parallel)
     → Cmok /skill/ (mockups) → User UAT
     → Laznik (arch + tests) → Bagnik (test gate)
     → Cmok /agent/ (build) + Mokash (docs, parallel) → Bagnik (code QA)
     → Zlydni (commit + archive)
```

### Agents

| Agent | Беларуская | Role | Model | Mythology |
|-------|-----------|------|-------|-----------|
| Bagnik | **Багнік** | Test gate & code QA | Opus | Болотный дух на дне — ничего не пропускает мимо; к нему самому всё приходит. |
| Cmok | **Цмок** | Build | Sonnet | Белорусский дракон — добродушный, справедливый, одаривает сокровищами. |
| Mokash | **Мокаш** | Documentation | Sonnet | Богиня прядения и учёта — ткёт нити знаний. |
| Veles | **Вялес** | AutoResearch ratchet (self-improve) | Sonnet | Хозяин Яви, Нави и Прави — управляет рatchet loop в трёх мирах. |
| Zlydni | **Злыдні** | Commits & version control | Haiku | Маленькие духи дома — тихо делают неизбежную работу. |

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
git submodule add https://github.com/bthos/agentic-kit agentic-kit
agentic-kit/init.sh
```

`init.sh` asks which IDE to target (**Claude Code**, **Cursor**, **GitHub Copilot**, or **all**). Non-interactive / CI:

```bash
agentic-kit/init.sh --ide=claude    # default behavior
agentic-kit/init.sh --ide=cursor
agentic-kit/init.sh --ide=github
agentic-kit/init.sh --ide=all       # all three  (alias: --ide=both)

# Agent / CI — no prompts at all:
agentic-kit/init.sh --non-interactive                  # claude (default)
agentic-kit/init.sh --non-interactive --ide=github
agentic-kit/init.sh -n --ide=all                       # short alias

# Other non-interactive bulk choices:
agentic-kit/init.sh --skip-all       # keep all existing kit paths, no prompts
agentic-kit/init.sh --overwrite-all  # replace all kit-managed files, no prompts
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

**Cursor:** each kit skill is copied to **`.cursor/skills/<name>/`** (with `SKILL.md` and bundled scripts) so [Cursor Agent Skills](https://cursor.com/docs/context/skills) pick them up. Each kit agent becomes a **[custom subagent](https://cursor.com/docs/context/subagents)** file under **`.cursor/agents/<stem>.md`** (generated copy with Cursor frontmatter: `model: inherit`, `is_background` from agent YAML `background`, etc.). `PIPELINE.md.template` is copied to **`AGENTS.md`** so the handoff protocol stays in the workspace. Invoke skills with **`/<skill-name>`**; invoke agents with **`/bagnik`**, **`/cmok-build`**, **`/mokash`**, **`/zlydni`**, or ask Agent to delegate.

**GitHub Copilot:** each agent becomes a `.github/agents/<name>.agent.md` custom agent (VS Code Copilot picks these up automatically). Each skill becomes a `.github/instructions/<name>.instructions.md` with `applyTo: '**'` so it applies to every chat. `PIPELINE.md.template` becomes `.github/copilot-instructions.md` — the workspace-wide instructions file Copilot always reads. Use `@<agentname>` in Copilot Chat to invoke a specific agent.

That's it.

## What `init.sh` does

**Always (all IDE modes):**

1. Copies `PROJECT.md.template` → `PROJECT.md` if none exists, or when you choose to overwrite an existing `PROJECT.md`. After any fresh copy from the template, optionally fills placeholders via the CLI that matches `--ide`: **`claude -p`** (Claude Code) for `claude`, **`agent -p --force`** ([Cursor Agent CLI](https://cursor.com/docs/cli/overview)) for `cursor`. Use the **`agent`** binary from [Cursor CLI install](https://cursor.com/docs/cli/installation) — the GUI **`cursor`** launcher is Electron-based and is not used here (passing `-p` to it triggers Chromium “unknown option” warnings). For `all` / `github`, it prefers `claude` if installed, otherwise `agent`. If stdin is not a TTY but `/dev/tty` exists, the Y/n prompt is read from `/dev/tty` so the step is not skipped silently in some IDE terminals.

The kit does **not** modify `.gitignore` for `.artefacts/` — add an ignore rule yourself if you want that directory untracked.

**`.agentic-kit.files`** (project root) records SHA-256 per kit-managed path. Add it to **`.gitignore`** if you do not want install state in version control.

Shared scripts live only under **`agentic-kit/tools/`** — run them from the **project root**, for example `agentic-kit/tools/validate-config.sh`.

**Claude Code (`claude` or `all`):**

2. Copies `agents/*.md` → `.claude/agents/` (records SHA-256 in **`.agentic-kit.files`**)
3. Copies `skills/*/` → `.claude/skills/` (same)
4. Copies `PIPELINE.md.template` → `CLAUDE.md` if none exists

**Cursor (`cursor` or `all`):**

5. Copies `skills/*/` → `.claude/skills/` (Cursor-only mode only — so paths like `.claude/skills/vadavik/new-feature.sh` in skill docs still work)
6. Copies `skills/*/` → `.cursor/skills/` (same relative layout as the kit — **re-run `init.sh` after `git submodule update`** to refresh)
7. Generates **`.cursor/agents/<stem>.md`** from each agent ([subagents](https://cursor.com/docs/context/subagents)). Optional YAML **`cursor_subagent_name`** or legacy **`cursor_rule_name`** sets the stem (e.g. Cmok build agent uses **`cmok-build`** so it does not collide with the **`cmok`** skill).
8. Copies `PIPELINE.md.template` → `AGENTS.md` with a kit-managed marker (for teardown)

**GitHub Copilot (`github` or `all`):**

9. Copies `skills/*/` → `.claude/skills/` (Copilot-only mode only — for bundled shell scripts)
10. Generates `.github/agents/<name>.agent.md` from each agent (**re-run `init.sh` after `git submodule update`** to refresh). Strips Claude-specific fields; adds standard Copilot `tools` list.
11. Generates `.github/instructions/<name>.instructions.md` from each skill with `applyTo: '**'`
12. Writes `.github/copilot-instructions.md` from `PIPELINE.md.template` (minus the `@PROJECT.md` line) with a kit-managed marker

The script is **idempotent** — existing kit-managed files prompt for overwrite (or **s** / **o** / **a** / **r** as above). For CI or scripts, use **`--force`** / **`--overwrite-all`** or **`--skip`** / **`--skip-all`** so nothing blocks on prompts. Each installed path’s content hash is tracked in **`.agentic-kit.files`** at the project root for **`teardown.sh`** (remove only if unchanged).

## Updating the kit

One command (pulls the submodule’s **remote** tracking branch, then runs `init.sh` with your usual flags):

```bash
agentic-kit/update.sh --ide=cursor --skip          # example: match how you first ran init
agentic-kit/update.sh --non-interactive --ide=all
agentic-kit/update.sh --no-pull --ide=github --skip   # submodule already updated; only re-run init
```

Equivalent manual steps:

```bash
git submodule update --remote agentic-kit
agentic-kit/init.sh   # same --ide= / --skip / etc. as before

git add agentic-kit
git commit -m "chore: update agentic-kit"
```

**What updates automatically:**
- New agents and skills — `init.sh` installs missing paths; existing files prompt (or follow **`--skip`** / **`--overwrite-all`**) and refresh hashes in **`.agentic-kit.files`** when overwritten
- Scripts under `agentic-kit/tools/` — they ship with the submodule; `git submodule update` brings new versions

**Cursor:** `.cursor/skills/` copies and `.cursor/agents/*.md` — after updating the submodule, run `init.sh` again (same `--ide=` as before) to refresh from the new kit sources (use **`--overwrite-all`** or answer prompts if kit files changed).

**GitHub Copilot:** same — `.github/agents/*.agent.md` and `.github/instructions/*.instructions.md`; re-run `init.sh --ide=github` (or `--ide=all`) after `git submodule update`.

**What does NOT update automatically:**
- `CLAUDE.md` — your project's copy is never overwritten. To pick up protocol changes, diff it against the new template:
  ```bash
  diff CLAUDE.md agentic-kit/PIPELINE.md.template
  ```
- `AGENTS.md` — same as `CLAUDE.md` for Cursor users; re-copy from template manually or delete and re-run `init.sh --ide=cursor`
- `PROJECT.md` — project-specific config, never touched
- Paths you keep via **`--skip`** / **`--skip-all`** during updates — unchanged until you overwrite

**Team members:** after pulling, run `git submodule update --init` to sync the submodule to the committed version (no `--remote` needed — that's only for the person pulling the new release).

## Overriding an agent or skill

Edit the installed copy under **`.claude/agents/`**, **`.claude/skills/`**, **`.cursor/skills/`**, etc. Once the file content differs from the last kit-installed bytes, its SHA-256 no longer matches **`.agentic-kit.files`**, so **`teardown.sh` leaves it in place** (treats it as manually edited).

To refresh from the kit later, remove the file or run **`init.sh`** with **`--overwrite-all`** / answer **o** at the prompt for that path.

```bash
cp agentic-kit/agents/bagnik.md .claude/agents/bagnik.md   # optional: reset from kit, then edit
# Edit .claude/agents/bagnik.md to your needs
```

For **Cursor** agent outputs, **`.cursor/agents/<stem>.md`** is generated from the kit; edit it locally or change **`agents/*.md` in the submodule** and re-run **`init.sh`**.

For **Cursor** skills, **`.cursor/skills/<name>/`** is a copy tree — edit in place or replace the directory; use **`--skip`** on future **`init.sh`** runs if you do not want the kit to overwrite your tree.

## Removing the kit

```bash
# Remove kit-managed copies (only where SHA-256 matches manifest), legacy symlinks/rules, AGENTS.md
agentic-kit/teardown.sh

# Or remove the above AND the submodule in one step
agentic-kit/teardown.sh --remove-submodule
```

`teardown.sh` deletes each tracked path only when the on-disk file matches the hash stored in **`.agentic-kit.files`** (pristine kit copy). It also removes legacy **symlinks** into the kit and legacy kit-managed **`.cursor/rules/*.mdc`**. Then it clears **`AGENTS.md`**, **`.github/agents/*.agent.md`**, **`.github/instructions/*.instructions.md`**, **`.github/copilot-instructions.md`** when those match their recorded hashes. Files you added yourself or edited by hand are left alone.

## Self-improving agents

The kit ships a three-layer self-tuning system so installed agents adapt to your project over time. All three layers are **opt-in** and never overwrite manual edits.

| Layer | What it does | Trigger |
|-------|--------------|---------|
| **1. Probe** | `tools/probe-project.sh` writes `.artefacts/PROJECT_PROFILE.md` (stack, frameworks, test/build commands, conventions). All skills read it before starting. | `agentic-kit/init.sh --tune` (or run `probe-project.sh` directly) |
| **2. Lesson distillation** | After each archived feature, `tools/distill-lessons.sh` turns `LESSONS.md` files into structured entries across the **memory tree** (see below). With `--target=agents` it also proposes targeted patches to specific agent files; review with `tools/apply-patches.sh`. | Manual: `distill-lessons.sh --target=both` |
| **3. AutoResearch ratchet (Veles)** | `agentic-kit/autoresearch/` — `program.md` (invariants + composite formula `accuracy − 0.3·cost`), `judge.md` (LLM-as-judge), `eval-set/` (auto-built from archive), `run.sh` (mutate → score → ratchet). Veles only accepts mutations that don't regress the composite metric and never edits tests, eval-set, or the judge. Mutation prompts now retrieve **prior rejected variants** and **top memory hits** before proposing — the **Karpathy AutoResearch** pattern that prevents reproposing already-failed ideas. | After Zlydni archive (auto, 2 rounds) or manual: `agentic-kit/autoresearch/run.sh --rounds=N` |

### Memory layers

Memory is organised as a five-layer tree modelled on **OpenClaw's self-evolving memory** (with all four of its known gaps explicitly closed). All layers are plain Markdown — `git diff`-able, hand-editable, no DB.

| Layer | Path | Purpose |
|-------|------|---------|
| **L0 — Enforcement** | `agents/*.md`, `skills/*/SKILL.md`, `autoresearch/program.md` | Hardened behavioural rules. Mutated only via `apply-patches.sh` or Veles. |
| **L1 — Hot State** | `.artefacts/SESSION-STATE.md` | Active feature, active agent, in-flight decisions. Auto-cleared after 24h by `tools/memory-rollover.sh`. |
| **L2 — Daily Memory** | `.artefacts/memory/YYYY-MM-DD.md` | Append-only log; agents write here as they work. |
| **L3 — Long-term structured** | `.artefacts/memory/{preferences,system,projects,decisions}.md` | Curated facts grouped by entity type with explicit `id`, `decided`, `entities`, `supersedes` fields. |
| **L4 — Root summary** | `.artefacts/MEMORY.md` | ≤2 KB index regenerated by `memory-promote.sh`. **Read first** by every skill. |
| **L5 — Semantic recall** | `tools/memory-search.sh` (+ optional `memory-search.py`) | TF-IDF / TF-IDF-cosine top-k retrieval over every layer. |

**Promotion state machine** (`tools/memory-promote.sh`):

```
observed → logged (L2) → curated (L3, 2-strike rule) → hardened (L0 patch) → stable
```

- **2-strike rule:** if the same fact appears in two daily files it auto-promotes to L3 with `confidence: medium` (no manual curation required).
- **Temporal awareness:** every L3 entry has `decided:`. New entries can declare `supersedes: mem_<id>`; the resolver tags the older entry `[superseded by …]` (no silent overwrites — the past is preserved).
- **Custom ontology:** fixed `entity_type` set (`person | project | file | tool | library | pattern | anti-pattern | decision`) gives `memory-search.sh` and skills a stable contract.
- **Mandatory write checklists** in every skill prompt close OpenClaw's "agent forgets to remember" gap — agents now have explicit triggers for when to append to L2.
- **Hardening:** `memory-promote.sh --propose-hardening` writes proposed agent patches to `.artefacts/proposed-patches/<agent>.md`; `tools/apply-patches.sh` lands them with manifest hash refresh.

**Common operations:**

```bash
# Initialise (idempotent; runs automatically inside init.sh)
agentic-kit/tools/memory-init.sh
agentic-kit/tools/memory-init.sh --migrate   # also ingests legacy SEMANTIC_MEMORY.md

# Search
agentic-kit/tools/memory-search.sh "auth flow"
agentic-kit/tools/memory-search.sh "auth flow" --layer l3 --top-k 10

# Curate (run after archive, or as a daily cron)
agentic-kit/tools/memory-promote.sh
agentic-kit/tools/memory-promote.sh --propose-hardening
agentic-kit/tools/memory-rollover.sh
```

Python TF-IDF (`memory-search.py`) is used automatically when `python3` + `scikit-learn` are available; otherwise the pure-bash search runs with no extra dependencies.

**Initialise AutoResearch:**

```bash
agentic-kit/autoresearch/run.sh --init
```

This builds `agentic-kit/autoresearch/eval-set/*.md` from existing archived features. Without an eval-set Veles cannot ratchet (it has no evidence). Cmok and Bagnik append per-run cost+accuracy to `.artefacts/features/<f>/metrics.jsonl` and `agentic-kit/autoresearch/runs/cost.jsonl` via `autoresearch/tools/record-metrics.sh` — the data Veles uses to compute the composite.

**Override the judge model** in `PROJECT.md`:

```markdown
- **Judge command:** `claude -p --allowedTools ''`   # default (Haiku-class)
```

Set this to any CLI that accepts the prompt on stdin and emits a single `0` or `1` to stdout (e.g. `gemini -p`).

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

Claude Code / Copilot use **`@agent`** for agents; Cursor uses **`/subagent-name`** for the same roles (see [subagents](https://cursor.com/docs/context/subagents)).

| What | How |
|------|-----|
| Write or update spec | `/vadavik` |
| Design UX | `/lojma` |
| Create UX mockups | `/cmok` |
| Architecture & tests | `/laznik` |
| Run test gate or code QA | `@bagnik` · **`/bagnik`** |
| Build | `@cmok` · **`/cmok-build`** |
| Write docs | `@mokash` · **`/mokash`** |
| Commit | `@zlydni` · **`/zlydni`** |

## Scripts

Each skill bundles its own script. Shared scripts live in `agentic-kit/tools/`. Run them from the **project root** so paths like `PROJECT.md` and `.artefacts/` resolve correctly.

### Skill scripts (bundled, copied into `.claude/skills/` by `init.sh`)

| Script | Invoked by | What it does |
|--------|-----------|--------------|
| `.claude/skills/vadavik/new-feature.sh <slug>` | Vadavik | Creates `.artefacts/features/YYYY-MM-DD-<slug>/` with `spec.md` skeleton and `handoff-log.md` |
| `.claude/skills/laznik/check-coverage.sh [feature-path]` | Laznik | Runs test command, prints results, appends coverage entry to `handoff-log.md` |

### Shared tools

| Script | What it does |
|--------|-------------|
| `agentic-kit/tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `PROJECT.md` (Cmok uses `patch`, Zlydni uses `minor`) — run from project root |
| `agentic-kit/tools/validate-config.sh` | Checks `PROJECT.md` for unfilled `<placeholder>` values — run after `init.sh` |
| `agentic-kit/tools/feature-status.sh` | Shows pipeline status for active features in `.artefacts/features/` |

### Lifecycle scripts

| Script | What it does |
|--------|-------------|
| `lib.sh` | Shared helpers (colors, paths, `AGENTIC_MARKER`) — sourced by `init.sh`, `update.sh`, and `teardown.sh`, not run directly |
| `update.sh` | `git submodule update --remote` for the kit, then `exec` into `init.sh` with the same arguments you pass (optional `--no-pull` to skip the fetch) |
| `init.sh` | IDE choice: Claude Code, Cursor, Copilot, or all; copies agents/skills and generates Cursor/Copilot outputs; copies `CLAUDE.md` / `AGENTS.md` / `PROJECT.md`; maintains **`.agentic-kit.files`** |
| `teardown.sh` | Removes kit-managed paths when SHA-256 matches **`.agentic-kit.files`**; legacy symlinks into the kit; legacy `.cursor/rules/*.mdc`; same hash logic for `AGENTS.md` and `.github/*`; `--remove-submodule` deinits git |

## Handoff protocol

See `CLAUDE.md` or `AGENTS.md` (Handoff Protocol section) for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference so the whole team shares the same pipeline version:

```bash
git add agentic-kit .gitmodules
git commit -m "chore: add agentic-kit submodule"
```

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
