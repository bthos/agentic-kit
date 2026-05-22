# Agentic Kit

A reusable AI development pipeline — 4 agents, 4 skills, and a structured handoff protocol. Installs one Claude-shaped layout (`.claude/agents/`, `.claude/skills/`) with two entry-point files at the project root: **`CLAUDE.md`** (read natively by Claude Code) and **`AGENTS.md`** (the cross-IDE convention — read by any workspace-aware tool that follows the AGENTS.md spec). One install covers every IDE.

The kit is **minimally invasive**: every kit-touched path is either inside `.akt/`, inside `.claude/`, or wrapped in a removable `<!-- agentic-kit:start --> … <!-- agentic-kit:end -->` block in `CLAUDE.md` / `AGENTS.md` / `.gitignore`. `teardown.sh` strips the block (or removes the file when its SHA-256 still matches the kit copy recorded in `.akt/.agentic-kit.files`), so manual edits are always preserved.

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
| Yaga | **Яга** | Debugging side-loop (hypothesis → instrument → observe → strip) | Opus | Баба Яга видит сокрытое — но требует, чтобы вы ответили на её загадки прежде, чем поможет. |
| Zlydni | **Злыдні** | Commits & version control | Haiku | Маленькие духи дома — тихо делают неизбежную работу. |

### Skills

| Skill    | Role                         |
|----------|------------------------------|
| Vadavik  | Spec & requirements          |
| Lojma    | UX design                    |
| Cmok     | UX mockups                   |
| Laznik   | Architecture & tests         |
| Yaga     | Hypothesis design for hard bugs |

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

> **Requirements.** Bash ≥ 4.0 (uses `read -a`, associative-style arrays, `[[ … ]]`). On Windows use **MSYS2 / Git Bash**. macOS / Linux work out of the box.

`tools/init.sh` installs one layout regardless of which IDE you use. Non-interactive / CI:

```bash
agentic-kit/tools/init.sh                                    # interactive
agentic-kit/tools/init.sh --non-interactive                  # CI / agent
agentic-kit/tools/init.sh -n                                 # short alias

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

Start a feature by invoking the `/vadavik` skill. Skills are invoked with `/<skill-name>`; agents with `@<agent-name>`. The kit added managed blocks to `CLAUDE.md` and `AGENTS.md` that both point at `.akt/PIPELINE.md` — your IDE picks up whichever entry-point file it reads.

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
├── .claude/                                  ← agent + skill copies
│
├── CLAUDE.md                                 ← Claude Code entry-point with managed include block
├── AGENTS.md                                 ← cross-IDE entry-point with the same managed block
│
└── .gitignore                                ← one kit-managed block (ephemeral + local bookkeeping)
```

Shared shell helpers live in **`agentic-kit/tools/lib.sh`** (sourced by `init.sh` / `update.sh` / `teardown.sh`, not run by hand). For a guided launcher use **`agentic-kit/agentic-kit.sh`** — a stage-aware menu that detects whether the kit is installed/configured and only offers actions that fit.

The IDE entry-point files are **never overwritten**. The kit only manages the content between its `<!-- agentic-kit:start -->` and `<!-- agentic-kit:end -->` markers — anything you add above or below is yours and survives every `init.sh` / `update.sh` / `teardown.sh` cycle.

### Managed `.gitignore` block

`init.sh` appends **one** contiguous block delimited by `# >>> agentic-kit (managed) >>>` … `# <<< agentic-kit (managed) <<<`. Inside it, comments separate **(a) runtime / ephemeral** paths from **(b) per-machine bookkeeping** (`.akt/.agentic-kit.cfg` and `.akt/.agentic-kit.files`). `teardown.sh` strips the **whole** block in one pass — you do not maintain two independent ignore sections.

**Do not** ignore the entire `.akt/` directory unless you also add negation rules so `PIPELINE.md` and `PROJECT.md` stay tracked — otherwise teammates never see the shared pipeline copy. The managed block lists only ephemeral paths plus the optional commented “ignore everything except PIPELINE/PROJECT” recipe for advanced setups.

## What `init.sh` does

1. Creates `.akt/` and copies the canonical pipeline doc + project config:
   - `.akt/PIPELINE.md` ← from `agentic-kit/templates/PIPELINE.md.template` (kit-managed; refreshed on `--force`)
   - `.akt/PROJECT.md` ← from `agentic-kit/templates/PROJECT.md.template` (your edits preserved unless `--force`)
2. Adds the managed `.gitignore` block described above — ephemeral directories and files under `.akt/`, plus `.akt/.agentic-kit.cfg` and `.akt/.agentic-kit.files`. **`PIPELINE.md` and `PROJECT.md` are not listed** so teams can commit them as usual.
3. After any fresh copy of `PROJECT.md`, optionally fills placeholders via **`claude -p`** (Claude Code). If stdin is not a TTY but `/dev/tty` exists, the Y/n prompt is read from `/dev/tty` so the step is not skipped silently in some IDE terminals.
4. Copies `agents/*.md` → `.claude/agents/` (records SHA-256 in **`.akt/.agentic-kit.files`**).
5. Copies `skills/*/` → `.claude/skills/` (same).
6. Adds the managed include block to `CLAUDE.md` and `AGENTS.md` (creates a stub if absent; appends to existing file if present).

**`.akt/.agentic-kit.files`** records SHA-256 per kit-managed path (paths are relative to the **project root**, e.g. `.claude/agents/bagnik.md`). It sits beside `.akt/.agentic-kit.cfg` and is listed in the managed `.gitignore` block so it stays local to each checkout.

Shared scripts live only under **`agentic-kit/tools/`** — run them from the **project root**, for example `agentic-kit/tools/validate-config.sh`.

The script is **idempotent** — existing kit-managed files prompt for overwrite (or **s** / **o** / **a** / **r** as above). For CI or scripts, use **`--force`** / **`--overwrite-all`** or **`--skip`** / **`--skip-all`** so nothing blocks on prompts. Each installed path's content hash is tracked in **`.akt/.agentic-kit.files`** for **`teardown.sh`** (remove only if unchanged). Managed include blocks are tracked with `block:<sha>` (block-only entries) or `stub:<sha>` (whole-file stubs we created from scratch).

## Updating the kit

One command (pulls the submodule's **remote** tracking branch, then runs `init.sh` with your usual flags):

```bash
agentic-kit/tools/update.sh --skip          # example: match how you first ran init
agentic-kit/tools/update.sh --non-interactive
agentic-kit/tools/update.sh --no-pull --skip   # submodule already updated; only re-run init
```

Equivalent manual steps:

```bash
git submodule update --remote agentic-kit
agentic-kit/tools/init.sh   # same --skip / --force / etc. as before

git add agentic-kit
git commit -m "chore: update agentic-kit"
```

**What updates automatically:**
- New agents and skills — `init.sh` installs missing paths; existing files prompt (or follow **`--skip`** / **`--overwrite-all`**) and refresh hashes in **`.akt/.agentic-kit.files`** when overwritten
- Scripts under `agentic-kit/tools/` — they ship with the submodule; `git submodule update` brings new versions
- `.akt/PIPELINE.md` — refreshed in place when you pass `--force` (or answer **o**); `update.sh` warns you if `agentic-kit/templates/PIPELINE.md.template` has changed since last init so you know when a refresh is worth running
- The managed blocks in `CLAUDE.md` and `AGENTS.md` — refreshed in place; everything outside the markers is preserved
- **Legacy IDE sweep** — `update.sh` automatically removes obsolete `.cursor/agents/`, `.cursor/skills/`, `.github/agents/`, `.github/instructions/`, and the managed block in `.github/copilot-instructions.md` left behind by prior kit versions. Only files whose SHA-256 still matches the kit manifest are removed; locally-edited files are skipped with a warning.

**What does NOT update automatically:**
- `.akt/PROJECT.md` — project-specific config, never touched (use `--force` to reset from the template)
- User content **outside** the managed block in `CLAUDE.md` / `AGENTS.md`
- Paths you keep via **`--skip`** / **`--skip-all`** during updates — unchanged until you overwrite

**Team members:** after pulling, run `git submodule update --init` to sync the submodule to the committed version (no `--remote` needed — that's only for the person pulling the new release).

## Overriding an agent or skill

Edit the installed copy under **`.claude/agents/`** or **`.claude/skills/`**. Once the file content differs from the last kit-installed bytes, its SHA-256 no longer matches **`.akt/.agentic-kit.files`**, so **`teardown.sh` leaves it in place** (treats it as manually edited).

To refresh from the kit later, remove the file or run **`init.sh`** with **`--overwrite-all`** / answer **o** at the prompt for that path.

```bash
cp agentic-kit/agents/bagnik.md .claude/agents/bagnik.md   # optional: reset from kit, then edit
# Edit .claude/agents/bagnik.md to your needs
```

## Removing the kit

```bash
# Strip managed blocks from CLAUDE.md and AGENTS.md, remove
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

- **Managed include blocks** — stripped from `CLAUDE.md` and `AGENTS.md`. If the file was a kit-created stub (manifest entry begins with `stub:`) and still matches that stub byte-for-byte, the whole file is removed. Otherwise the file is kept and only the marked block is excised — your custom content survives.
- **Managed `.gitignore` block** — stripped using the same start/end markers; the rest of your `.gitignore` is untouched.
- **Agent / skill copies** under `.claude/` — deleted only when the on-disk SHA-256 still matches the value recorded in `.akt/.agentic-kit.files`. Files you edited by hand are left alone (the script reports them as "modified locally").
- **`.akt/PIPELINE.md`** — same SHA-256 check.
- **`.akt/PROJECT.md`** — kept by default (it has your project config); removed only with `--full-clean` (and only after a y/N prompt unless `--yes` is passed).
- **`.akt/{memory,features,archive,proposed-patches}/`** — never touched by teardown. They are your project's runtime state.
- **`.akt/scratch/`** — swept by `--full-clean`. Pure ephemera (commit messages, PR bodies, large request payloads) with no user state.
- **Legacy artefacts** — old `.cursor/agents/`, `.cursor/skills/`, `.github/agents/`, `.github/instructions/`, the managed block in `.github/copilot-instructions.md`, and any relative symlinks pointing into the kit are also cleaned up if their hashes match.

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

| What | How |
|------|-----|
| Write or update spec | `/vadavik` |
| Design UX | `/lojma` |
| Create UX mockups | `/cmok` |
| Architecture & tests | `/laznik` |
| Run test gate or code QA | `@bagnik` |
| Build | `@cmok` |
| Write docs | `@mokash` |
| Investigate a hard bug (hypothesis) | `/yaga` |
| Investigate a hard bug (instrument + observe + strip) | `@yaga` |
| Commit | `@zlydni` |

## Scripts

Each skill bundles its own script. Shared scripts live in `agentic-kit/tools/`. Run them from the **project root** so paths like `.akt/PROJECT.md` resolve correctly.

### Skill scripts (bundled, copied into `.claude/skills/` by `init.sh`)

| Script | Invoked by | What it does |
|--------|-----------|--------------|
| `.claude/skills/vadavik/new-feature.sh <slug>` | Vadavik | Creates `.akt/features/YYYY-MM-DD-<slug>/` with `spec.md` skeleton and `handoff-log.md` |
| `.claude/skills/laznik/check-coverage.sh [feature-path]` | Laznik | Runs test command, prints results, appends coverage entry to `handoff-log.md` |
| `.claude/skills/yaga/new-investigation.sh <slug>` | Yaga | Creates `.akt/debug/YYYY-MM-DD-<slug>/` with `hypothesis.md`, `instrumentation-log.md`, `findings.md`, `handoff-log.md` skeletons. Probe snippets live under `.claude/skills/yaga/templates/probes/`. |

### Shared tools

| Script | What it does |
|--------|-------------|
| `agentic-kit/tools/bump-version.sh patch\|minor` | Bumps version in all files listed in `.akt/PROJECT.md` (Cmok uses `patch`, Zlydni uses `minor`) — run from project root |
| `agentic-kit/tools/validate-config.sh` | Checks `.akt/PROJECT.md` for unfilled `<placeholder>` values — run after `init.sh` |
| `agentic-kit/tools/feature-status.sh` | Shows pipeline status for active features in `.akt/features/` |
| `agentic-kit/tools/yaga-log-server.py` | Yaga's local debug log server (Python 3 stdlib, loopback only). Captures runtime probes from instrumented code into `<investigation>/runtime.jsonl`. Endpoints: `/log`, `/console`, `/network`, `/tail`, `/stream`, `/shutdown`. |
| `agentic-kit/tools/yaga-log-server.sh` | Degraded `nc`-based fallback when `python3` is unavailable. Same investigation contract, no SSE. |
| `agentic-kit/tools/yaga-strip.sh <id>` | Removes every line carrying the `YAGA:<id>` sentinel. Self-blocks (non-zero exit) if residue remains. |

### Lifecycle scripts

| Script | What it does |
|--------|-------------|
| `agentic-kit.sh` | **Recommended human entry point.** Stage-aware interactive launcher. Detects install state (not installed / needs config / ready) and surfaces only actions that make sense at the current stage: `init`, `probe`, edit + `validate` `PROJECT.md`, `update`, `teardown`, feature `status`, memory `search`, version `bump`, memory `rollover` / `promote`, `distill` lessons, apply `patches`. Press `h` inside the menu for one-line descriptions. |
| `tools/init.sh` | Sets up `.akt/`; copies agents to `.claude/agents/` and skills to `.claude/skills/`; manages include blocks in `CLAUDE.md` and `AGENTS.md`; manages the `.gitignore` block; maintains **`.akt/.agentic-kit.files`**. |
| `tools/update.sh` | `git submodule update --remote` for the kit, then re-runs `tools/init.sh` with the same arguments you pass (optional `--no-pull` to skip the fetch). After the refresh, sweeps obsolete Cursor/Copilot artefacts from prior kit versions (manifest-safety preserved). Warns if `templates/PIPELINE.md.template` drifted since last init. |
| `tools/teardown.sh` | Strips managed include blocks from `CLAUDE.md` and `AGENTS.md`; strips the managed `.gitignore` block; removes kit-installed copies when SHA-256 matches **`.akt/.agentic-kit.files`**; sweeps any legacy `.cursor/` and `.github/` artefacts. `--full-clean` also removes `.akt/PROJECT.md`, `.akt/.agentic-kit.cfg`, and `.akt/scratch/`; `--remove-submodule` deinits git. |
| `agentic-kit/tools/lib.sh` | Shared helpers (colors, paths, managed blocks, `.gitignore` renderer) — sourced by `tools/init.sh`, `tools/update.sh`, `tools/teardown.sh`, and some tools; not run directly. |

## Handoff protocol

See `.akt/PIPELINE.md` (Handoff Protocol section) — referenced from `CLAUDE.md` and `AGENTS.md` via the managed include block — for the full structured handoff format, handoff map, and agent-specific checklists.

## Team use

Commit the submodule reference, the canonical pipeline, and the project config so the whole team shares the same pipeline version:

```bash
git add agentic-kit .gitmodules
git add .akt/PIPELINE.md .akt/PROJECT.md
git add CLAUDE.md AGENTS.md
git add .gitignore                                              # managed block (recommended)
# (.akt/.agentic-kit.cfg and .agentic-kit.files are gitignored — do not commit)
git commit -m "chore: add agentic-kit submodule"
```

The managed `.gitignore` block excludes ephemeral tree paths and **`.akt/.agentic-kit.files`** / **`.akt/.agentic-kit.cfg`** so those stay local to each developer.

Team members clone with `git clone --recurse-submodules` or run `git submodule update --init` after cloning.
