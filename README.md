# Agentic Kit

A reusable AI development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Works with **Claude Code** (native `.claude/` layout), **Cursor** (copied `.cursor/skills/` + generated [`.cursor/agents/*.md` subagents](https://cursor.com/docs/context/subagents)), and **GitHub Copilot** (generated `.github/agents/*.agent.md` + `.github/instructions/*.instructions.md`).

The kit is **minimally invasive**: every kit-touched path is either inside `.akt/`, the IDE folder (`.claude/`, `.cursor/`, `.github/`), or wrapped in a removable `<!-- agentic-kit:start --> … <!-- agentic-kit:end -->` block. `teardown.sh` strips the block (or removes the file when its SHA-256 still matches the kit copy recorded in `.akt/.agentic-kit.files`), so manual edits are always preserved.

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

# Interactive launcher — recommended for humans. Detects install stage and
# only offers actions that make sense (init when not installed, validate +
# edit PROJECT.md when unconfigured, full menu once ready).
agentic-kit/agentic-kit.sh

# Or call init.sh directly — recommended for scripts and CI.
agentic-kit/tools/init.sh
```

`agentic-kit/agentic-kit.sh` is a stage-aware menu: at stage **0 (not installed)** it only shows `init`; at stage **1 (needs config)** it adds `probe`, `edit PROJECT.md`, `validate`, `teardown`; at stage **2 (ready)** it surfaces the full set — feature status, memory search, version bumps, memory rollover/promotion, distill lessons, apply patches. Press `h` for inline descriptions of every action. For CI / agents, pass an action as a positional argument: `agentic-kit/agentic-kit.sh status` runs once and exits; `agentic-kit/agentic-kit.sh --list-json` dumps the action registry as JSON; `agentic-kit/agentic-kit.sh --help` prints the full reference.

> **Requirements.** Bash ≥ 4.0 (uses `read -a`, associative-style arrays, `[[ … ]]`). On Windows use **MSYS2 / Git Bash**; `tools/init.sh` already falls back to PowerShell to discover the Cursor `agent` CLI when it's not on the MSYS PATH. macOS / Linux work out of the box.

`tools/init.sh` asks which IDE to target (**Claude Code**, **Cursor**, **GitHub Copilot**, or **all**). Non-interactive / CI:

```bash
agentic-kit/tools/init.sh --ide=claude    # default behavior
agentic-kit/tools/init.sh --ide=cursor
agentic-kit/tools/init.sh --ide=github
agentic-kit/tools/init.sh --ide=all       # all three  (alias: --ide=both)

# Agent / CI — no prompts at all:
agentic-kit/tools/init.sh --non-interactive                  # claude (default)
agentic-kit/tools/init.sh --non-interactive --ide=github
agentic-kit/tools/init.sh -n --ide=all                       # short alias

# Other non-interactive bulk choices:
agentic-kit/tools/init.sh --skip-all       # keep all existing kit paths, no prompts
agentic-kit/tools/init.sh --overwrite-all  # replace all kit-managed files, no prompts
```

When a path already exists, the interactive prompt is: **s**kip this file, **o**verwrite this file, overwrite **a**ll remaining, or skip **r**est (this file and every later conflict).

`--non-interactive` / `-n` is the recommended flag for agents and CI (aliases: `--yes`, `-y`): it skips existing files, suppresses all Y/n prompts, and prints a structured **`[AGENT ACTION REQUIRED]`** block instructing the calling agent to fill `.akt/PROJECT.md` itself — no nested CLI process is spawned. The agent reads the script output and uses its own tools (Read / Glob / Edit) to replace the placeholders.

Then open **`.akt/PROJECT.md`** and fill in the **Project-Specific Configuration** section:

```markdown
- Test command:   `npm test`
- Build command:  `npm run build`
- Version files:  `package.json, manifest.json`
```

**Claude Code:** start a feature with `/vadavik`. The kit added a small managed block to `CLAUDE.md` that points at `.akt/PIPELINE.md`.

**Cursor:** each kit skill is copied to **`.cursor/skills/<name>/`** (with `SKILL.md` and bundled scripts) so [Cursor Agent Skills](https://cursor.com/docs/context/skills) pick them up. Each kit agent becomes a **[custom subagent](https://cursor.com/docs/context/subagents)** file under **`.cursor/agents/<stem>.md`** (generated copy with Cursor frontmatter: `model: inherit`, `is_background` from agent YAML `background`, etc.). The kit added a managed block to **`AGENTS.md`** that includes `.akt/PIPELINE.md`. Invoke skills with **`/<skill-name>`**; invoke agents with **`/bagnik`**, **`/cmok-build`**, **`/mokash`**, **`/zlydni`**, or ask Agent to delegate.

**GitHub Copilot:** each agent becomes a `.github/agents/<name>.agent.md` custom agent (VS Code Copilot picks these up automatically). Each skill becomes a `.github/instructions/<name>.instructions.md` with `applyTo: '**'` so it applies to every chat. The kit added a managed block to **`.github/copilot-instructions.md`** that includes `.akt/PIPELINE.md`. Use `@<agentname>` in Copilot Chat to invoke a specific agent.

That's it.

## Layout — what gets written

```
.
├── agentic-kit/                              ← the submodule (read-only)
├── .akt/                   ← all kit-managed project state lives here
│   ├── PIPELINE.md                           ← canonical pipeline doc (refreshed on update)
│   ├── PROJECT.md                            ← project-specific config (you edit; kept on update)
│   ├── PROJECT_PROFILE.md                    ← (optional, --tune) probed stack/conventions
│   ├── MEMORY.md                             ← L4 root summary (≤2 KB index)
│   ├── SESSION-STATE.md                      ← L1 hot state
│   ├── memory/YYYY-MM-DD.md                  ← L2 daily log
│   ├── memory/{preferences,system,projects,decisions}.md   ← L3 curated facts
│   ├── proposed-patches/<agent>.md           ← agent hardening patches awaiting review
│   ├── features/<slug>/                      ← active feature (spec, UX, tech plan, handoffs)
│   ├── archive/<slug>/                       ← completed features (moved by Zlydni)
│   ├── .agentic-kit.cfg                      ← saved IDE + pipeline template SHA (gitignored)
│   └── .agentic-kit.files                    ← SHA manifest for teardown (gitignored)
│
├── .claude/   .cursor/   .github/            ← one folder per IDE you targeted
│
├── CLAUDE.md                                 ← (--ide=claude / all) IDE entry point with managed
├── AGENTS.md                                 ← (--ide=cursor / all)  block pointing at PIPELINE.md;
├── .github/copilot-instructions.md           ← (--ide=github / all)  user content preserved
│
└── .gitignore                                ← one kit-managed block (ephemeral + local bookkeeping)
```

Shared shell helpers live in **`agentic-kit/tools/lib.sh`** (sourced by `init.sh` / `update.sh` / `teardown.sh`, not run by hand). For a guided launcher use **`agentic-kit/agentic-kit.sh`** — a stage-aware menu that detects whether the kit is installed/configured and only offers actions that fit.

The IDE entry-point files are **never overwritten**. The kit only manages the content between its `<!-- agentic-kit:start -->` and `<!-- agentic-kit:end -->` markers — anything you add above or below is yours and survives every `init.sh` / `update.sh` / `teardown.sh` cycle.

### Managed `.gitignore` block

`init.sh` appends **one** contiguous block delimited by `# >>> agentic-kit (managed) >>>` … `# <<< agentic-kit (managed) <<<`. Inside it, comments separate **(a) runtime / ephemeral** paths from **(b) per-machine bookkeeping** (`.akt/.agentic-kit.cfg` and `.akt/.agentic-kit.files`). `teardown.sh` strips the **whole** block in one pass — you do not maintain two independent ignore sections.

**Do not** ignore the entire `.akt/` directory unless you also add negation rules so `PIPELINE.md` and `PROJECT.md` stay tracked — otherwise teammates never see the shared pipeline copy. The managed block lists only ephemeral paths plus the optional commented “ignore everything except PIPELINE/PROJECT” recipe for advanced setups.

## What `init.sh` does

**Always (all IDE modes):**

1. Creates `.akt/` and copies the canonical pipeline doc + project config:
   - `.akt/PIPELINE.md` ← from `agentic-kit/templates/PIPELINE.md.template` (kit-managed; refreshed on `--force`)
   - `.akt/PROJECT.md` ← from `agentic-kit/templates/PROJECT.md.template` (your edits preserved unless `--force`)
2. Adds the managed `.gitignore` block described above — ephemeral directories and files under `.akt/`, plus `.akt/.agentic-kit.cfg` and `.akt/.agentic-kit.files`. **`PIPELINE.md` and `PROJECT.md` are not listed** so teams can commit them as usual.
3. After any fresh copy of `PROJECT.md`, optionally fills placeholders via the CLI that matches `--ide`: **`claude -p`** (Claude Code) for `claude`, **`agent -p --force`** ([Cursor Agent CLI](https://cursor.com/docs/cli/overview)) for `cursor`. Use the **`agent`** binary from [Cursor CLI install](https://cursor.com/docs/cli/installation) — the GUI **`cursor`** launcher is Electron-based and is not used here. For `all` / `github`, it prefers `claude` if installed, otherwise `agent`. If stdin is not a TTY but `/dev/tty` exists, the Y/n prompt is read from `/dev/tty` so the step is not skipped silently in some IDE terminals.

**`.akt/.agentic-kit.files`** records SHA-256 per kit-managed path (paths are still relative to the **project root**, e.g. `.claude/agents/bagnik.md`). It sits beside `.akt/.agentic-kit.cfg` and is listed in the managed `.gitignore` block so it stays local to each checkout.

Shared scripts live only under **`agentic-kit/tools/`** — run them from the **project root**, for example `agentic-kit/tools/validate-config.sh`.

**Claude Code (`claude` or `all`):**

4. Copies `agents/*.md` → `.claude/agents/` (records SHA-256 in **`.akt/.agentic-kit.files`**)
5. Copies `skills/*/` → `.claude/skills/` (same)
6. Adds the managed include block to `CLAUDE.md` (creates a stub if absent; appends to existing file if present)

**Cursor (`cursor` or `all`):**

7. Copies `skills/*/` → `.claude/skills/` (Cursor-only mode only — so paths like `.claude/skills/vadavik/new-feature.sh` in skill docs still work)
8. Copies `skills/*/` → `.cursor/skills/` (same relative layout as the kit — **re-run `init.sh` after `git submodule update`** to refresh)
9. Generates **`.cursor/agents/<stem>.md`** from each agent ([subagents](https://cursor.com/docs/context/subagents)). Optional YAML **`cursor_subagent_name`** or legacy **`cursor_rule_name`** sets the stem (e.g. Cmok build agent uses **`cmok-build`** so it does not collide with the **`cmok`** skill).
10. Adds the managed include block to `AGENTS.md` (creates a stub if absent; appends if present)

**GitHub Copilot (`github` or `all`):**

11. Copies `skills/*/` → `.claude/skills/` (Copilot-only mode only — for bundled shell scripts)
12. Generates `.github/agents/<name>.agent.md` from each agent (**re-run `init.sh` after `git submodule update`** to refresh). Strips Claude-specific fields; adds standard Copilot `tools` list.
13. Generates `.github/instructions/<name>.instructions.md` from each skill with `applyTo: '**'`
14. Adds the managed include block to `.github/copilot-instructions.md` (creates a stub if absent; appends if present)

The script is **idempotent** — existing kit-managed files prompt for overwrite (or **s** / **o** / **a** / **r** as above). For CI or scripts, use **`--force`** / **`--overwrite-all`** or **`--skip`** / **`--skip-all`** so nothing blocks on prompts. Each installed path's content hash is tracked in **`.akt/.agentic-kit.files`** for **`teardown.sh`** (remove only if unchanged). Managed include blocks are tracked with `block:<sha>` (block-only entries) or `stub:<sha>` (whole-file stubs we created from scratch).

## Updating the kit

One command (pulls the submodule's **remote** tracking branch, then runs `init.sh` with your usual flags):

```bash
agentic-kit/tools/update.sh --ide=cursor --skip          # example: match how you first ran init
agentic-kit/tools/update.sh --non-interactive --ide=all
agentic-kit/tools/update.sh --no-pull --ide=github --skip   # submodule already updated; only re-run init
```

Equivalent manual steps:

```bash
git submodule update --remote agentic-kit
agentic-kit/tools/init.sh   # same --ide= / --skip / etc. as before

git add agentic-kit
git commit -m "chore: update agentic-kit"
```

**What updates automatically:**
- New agents and skills — `init.sh` installs missing paths; existing files prompt (or follow **`--skip`** / **`--overwrite-all`**) and refresh hashes in **`.akt/.agentic-kit.files`** when overwritten
- Scripts under `agentic-kit/tools/` — they ship with the submodule; `git submodule update` brings new versions
- `.akt/PIPELINE.md` — refreshed in place when you pass `--force` (or answer **o**); `update.sh` warns you if `agentic-kit/templates/PIPELINE.md.template` has changed since last init so you know when a refresh is worth running
- The managed blocks in `CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md` — refreshed in place; everything outside the markers is preserved

**Cursor:** `.cursor/skills/` copies and `.cursor/agents/*.md` — after updating the submodule, run `init.sh` again (same `--ide=` as before) to refresh from the new kit sources (use **`--overwrite-all`** or answer prompts if kit files changed).

**GitHub Copilot:** same — `.github/agents/*.agent.md` and `.github/instructions/*.instructions.md`; re-run `init.sh --ide=github` (or `--ide=all`) after `git submodule update`.

**What does NOT update automatically:**
- `.akt/PROJECT.md` — project-specific config, never touched (use `--force` to reset from the template)
- User content **outside** the managed block in `CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md`
- Paths you keep via **`--skip`** / **`--skip-all`** during updates — unchanged until you overwrite

**Team members:** after pulling, run `git submodule update --init` to sync the submodule to the committed version (no `--remote` needed — that's only for the person pulling the new release).

## Overriding an agent or skill

Edit the installed copy under **`.claude/agents/`**, **`.claude/skills/`**, **`.cursor/skills/`**, etc. Once the file content differs from the last kit-installed bytes, its SHA-256 no longer matches **`.akt/.agentic-kit.files`**, so **`teardown.sh` leaves it in place** (treats it as manually edited).

To refresh from the kit later, remove the file or run **`init.sh`** with **`--overwrite-all`** / answer **o** at the prompt for that path.

```bash
cp agentic-kit/agents/bagnik.md .claude/agents/bagnik.md   # optional: reset from kit, then edit
# Edit .claude/agents/bagnik.md to your needs
```

For **Cursor** agent outputs, **`.cursor/agents/<stem>.md`** is generated from the kit; edit it locally or change **`agents/*.md` in the submodule** and re-run **`init.sh`**.

For **Cursor** skills, **`.cursor/skills/<name>/`** is a copy tree — edit in place or replace the directory; use **`--skip`** on future **`init.sh`** runs if you do not want the kit to overwrite your tree.

## Removing the kit

```bash
# Strip managed blocks from CLAUDE.md/AGENTS.md/copilot-instructions.md, remove
# kit-installed copies (only where SHA-256 still matches the manifest), strip the
# managed .gitignore block, remove .akt/PIPELINE.md.
agentic-kit/tools/teardown.sh

# Same plus: delete .akt/PROJECT.md (after y/N confirmation)
# and rmdir .akt/ if empty.
agentic-kit/tools/teardown.sh --full-clean

# Same as the first plus: deinit and remove the kit submodule.
agentic-kit/tools/teardown.sh --remove-submodule

# Preview without touching anything.
agentic-kit/tools/teardown.sh --dry-run
```

`teardown.sh` is conservative by design:

- **Managed include blocks** — stripped from `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`. If the file was a kit-created stub (manifest entry begins with `stub:`) and still matches that stub byte-for-byte, the whole file is removed. Otherwise the file is kept and only the marked block is excised — your custom content survives.
- **Managed `.gitignore` block** — stripped using the same start/end markers; the rest of your `.gitignore` is untouched.
- **Agent / skill copies** under `.claude/`, `.cursor/`, `.github/` — deleted only when the on-disk SHA-256 still matches the value recorded in `.akt/.agentic-kit.files`. Files you edited by hand are left alone (the script reports them as "modified locally").
- **`.akt/PIPELINE.md`** — same SHA-256 check.
- **`.akt/PROJECT.md`** — kept by default (it has your project config); removed only with `--full-clean` (and only after a y/N prompt unless `--yes` is passed).
- **`.akt/{memory,features,archive,proposed-patches}/`** — never touched by teardown. They are your project's runtime state.
- **Legacy artefacts** — relative symlinks pointing into the kit and old `.cursor/rules/*.mdc` files are also cleaned up if their hashes match.

## Self-improving agents

The kit ships a three-layer self-tuning system so installed agents adapt to your project over time. All three layers are **opt-in** and never overwrite manual edits.

| Layer | What it does | Trigger |
|-------|--------------|---------|
| **1. Probe** | `tools/probe-project.sh` writes `.akt/PROJECT_PROFILE.md` (stack, frameworks, test/build commands, conventions). All skills read it before starting. | `agentic-kit/tools/init.sh --tune` (or run `probe-project.sh` directly) |
| **2. Lesson distillation** | After each archived feature, `tools/distill-lessons.sh` turns `LESSONS.md` files into structured entries across the **memory tree** (see below). With `--target=agents` it also proposes targeted patches to specific agent files; review with `tools/apply-patches.sh`. | Manual: `distill-lessons.sh --target=both` |
| **3. AutoResearch ratchet (Veles)** | `agentic-kit/autoresearch/` — `program.md` (invariants + composite formula `accuracy − 0.3·cost`), `judge.md` (LLM-as-judge), `eval-set/` (auto-built from archive), `run.sh` (mutate → score → ratchet). Veles only accepts mutations that don't regress the composite metric and never edits tests, eval-set, or the judge. Mutation prompts now retrieve **prior rejected variants** and **top memory hits** before proposing — the **Karpathy AutoResearch** pattern that prevents reproposing already-failed ideas. | After Zlydni archive (auto, 2 rounds) or manual: `agentic-kit/autoresearch/run.sh --rounds=N` |

### Memory layers

Memory is organised as a five-layer tree modelled on **OpenClaw's self-evolving memory** (with all four of its known gaps explicitly closed). All layers are plain Markdown — `git diff`-able, hand-editable, no DB.

| Layer | Path | Purpose |
|-------|------|---------|
| **L0 — Enforcement** | `agents/*.md`, `skills/*/SKILL.md`, `autoresearch/program.md` | Hardened behavioural rules. Mutated only via `apply-patches.sh` or Veles. |
| **L1 — Hot State** | `.akt/SESSION-STATE.md` | Active feature, active agent, in-flight decisions. Auto-cleared after 24h by `memory/tools/rollover.sh`. |
| **L2 — Daily Memory** | `.akt/memory/YYYY-MM-DD.md` | Append-only log; agents write here as they work. |
| **L3 — Long-term structured** | `.akt/memory/{preferences,system,projects,decisions}.md` | Curated facts grouped by entity type with explicit `id`, `decided`, `entities`, `supersedes` fields. |
| **L4 — Root summary** | `.akt/MEMORY.md` | ≤2 KB index regenerated by `memory-promote.sh`. **Read first** by every skill. |
| **L5 — Semantic recall** | `memory/tools/search.sh` (+ optional `search.py`) | TF-IDF / TF-IDF-cosine top-k retrieval over every layer. |

**Promotion state machine** (`memory/tools/promote.sh`):

```
observed → logged (L2) → curated (L3, 2-strike rule) → hardened (L0 patch) → stable
```

- **2-strike rule:** if the same fact appears in two daily files it auto-promotes to L3 with `confidence: medium` (no manual curation required).
- **Temporal awareness:** every L3 entry has `decided:`. New entries can declare `supersedes: mem_<id>`; the resolver tags the older entry `[superseded by …]` (no silent overwrites — the past is preserved).
- **Custom ontology:** fixed `entity_type` set (`person | project | file | tool | library | pattern | anti-pattern | decision`) gives `memory-search.sh` and skills a stable contract.
- **Mandatory write checklists** in every skill prompt close OpenClaw's "agent forgets to remember" gap — agents now have explicit triggers for when to append to L2.
- **Hardening:** `memory-promote.sh --propose-hardening` writes proposed agent patches to `.akt/proposed-patches/<agent>.md`; `tools/apply-patches.sh` lands them with manifest hash refresh.

**Common operations:**

```bash
# Initialise (idempotent; runs automatically inside init.sh)
agentic-kit/memory/tools/init.sh

# Search
agentic-kit/memory/tools/search.sh "auth flow"
agentic-kit/memory/tools/search.sh "auth flow" --layer l3 --top-k 10

# Curate (run after archive, or as a daily cron)
agentic-kit/memory/tools/promote.sh
agentic-kit/memory/tools/promote.sh --propose-hardening
agentic-kit/memory/tools/rollover.sh
```

Python TF-IDF (`memory-search.py`) is used automatically when `python3` + `scikit-learn` are available; otherwise the pure-bash search runs with no extra dependencies.

> **Override the artefacts directory.** Every memory / autoresearch script honours `ARTEFACTS_DIR` (e.g. `ARTEFACTS_DIR=.kit-state agentic-kit/memory/tools/search.sh "auth"`). The default is `.akt`, which `init.sh` records in `.akt/.agentic-kit.cfg` as `ARTEFACTS_DIR=…` for drift detection and tooling.

**Initialise AutoResearch:**

```bash
agentic-kit/autoresearch/run.sh --init
```

This builds `agentic-kit/autoresearch/eval-set/*.md` from existing archived features. Without an eval-set Veles cannot ratchet (it has no evidence). Cmok and Bagnik append per-run cost+accuracy to `.akt/features/<f>/metrics.jsonl` and `agentic-kit/autoresearch/runs/cost.jsonl` via `autoresearch/tools/record-metrics.sh` — the data Veles uses to compute the composite.

**Override the judge model** in `.akt/PROJECT.md`:

```markdown
- **Judge command:** `claude -p --allowedTools ''`   # default (Haiku-class)
```

Set this to any CLI that accepts the prompt on stdin and emits a single `0` or `1` to stdout (e.g. `gemini -p`).

## Feature artifacts

All feature work lives under `.akt/`:

```
.akt/
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

Each skill bundles its own script. Shared scripts live in `agentic-kit/tools/`. Run them from the **project root** so paths like `.akt/PROJECT.md` resolve correctly.

### Skill scripts (bundled, copied into `.claude/skills/` by `init.sh`)

| Script | Invoked by | What it does |
|--------|-----------|--------------|
| `.claude/skills/vadavik/new-feature.sh <slug>` | Vadavik | Creates `.akt/features/YYYY-MM-DD-<slug>/` with `spec.md` skeleton and `handoff-log.md` |
| `.claude/skills/laznik/check-coverage.sh [feature-path]` | Laznik | Runs test command, prints results, appends coverage entry to `handoff-log.md` |

### Shared tools

| Script | What it does |
|--------|-------------|
| `agentic-kit/tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `.akt/PROJECT.md` (Cmok uses `patch`, Zlydni uses `minor`) — run from project root |
| `agentic-kit/tools/validate-config.sh` | Checks `.akt/PROJECT.md` for unfilled `<placeholder>` values — run after `init.sh` |
| `agentic-kit/tools/feature-status.sh` | Shows pipeline status for active features in `.akt/features/` |

### Lifecycle scripts

| Script | What it does |
|--------|-------------|
| `agentic-kit.sh` | **Recommended human entry point.** Stage-aware interactive launcher. Detects install state (not installed / needs config / ready) and surfaces only actions that make sense at the current stage: `init`, `probe`, edit + `validate` `PROJECT.md`, `update`, `teardown`, feature `status`, memory `search`, version `bump`, memory `rollover` / `promote`, `distill` lessons, apply `patches`. Press `h` inside the menu for one-line descriptions. |
| `tools/init.sh` | IDE choice: Claude Code, Cursor, Copilot, or all. Sets up `.akt/`; copies agents/skills; generates Cursor/Copilot outputs; manages include blocks in `CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md`; manages the `.gitignore` block; maintains **`.akt/.agentic-kit.files`**. |
| `tools/update.sh` | `git submodule update --remote` for the kit, then `exec` into `tools/init.sh` with the same arguments you pass (optional `--no-pull` to skip the fetch). Warns if `templates/PIPELINE.md.template` drifted since last init. |
| `tools/teardown.sh` | Strips managed include blocks; strips the managed `.gitignore` block; removes kit-installed copies when SHA-256 matches **`.akt/.agentic-kit.files`**; removes legacy symlinks and `.cursor/rules/*.mdc`; `--full-clean` also removes `.akt/PROJECT.md` and `.akt/.agentic-kit.cfg`; `--remove-submodule` deinits git. |
| `agentic-kit/tools/lib.sh` | Shared helpers (colors, paths, managed blocks, `.gitignore` renderer) — sourced by `tools/init.sh`, `tools/update.sh`, `tools/teardown.sh`, and some tools; not run directly. |

## Handoff protocol

See `.akt/PIPELINE.md` (Handoff Protocol section) — referenced from `CLAUDE.md`, `AGENTS.md`, and `.github/copilot-instructions.md` via the managed include block — for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference, the canonical pipeline, and the project config so the whole team shares the same pipeline version:

```bash
git add agentic-kit .gitmodules
git add .akt/PIPELINE.md .akt/PROJECT.md
git add CLAUDE.md AGENTS.md .github/copilot-instructions.md   # whichever you targeted
git add .gitignore                                              # managed block (recommended)
# (.akt/.agentic-kit.cfg and .agentic-kit.files are gitignored — do not commit)
git commit -m "chore: add agentic-kit submodule"
```

The managed `.gitignore` block excludes ephemeral tree paths and **`.akt/.agentic-kit.files`** / **`.akt/.agentic-kit.cfg`** so those stay local to each developer.

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
