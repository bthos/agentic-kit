# Changelog

All notable changes to **Talaka** are documented here. The kit is consumed
as a git submodule, so downstream projects pin a specific commit — this log is
how you tell which behaviors changed between pinned revisions.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to a loose semantic-versioning intent (no formal version
tags yet — entries are dated and grouped by submodule HEAD).

## [Unreleased]

### Added — `decay-variants.sh` (Навь retention)
- **`autoresearch/tools/decay-variants.sh`** — the one sanctioned way to prune variant
  history (`.tlk/autoresearch/variants/`). Deletes round snapshots older than a retention
  window (`--days`, default 90), records each pruned round in `runs/decay.jsonl` *before*
  removal so the audit trail outlives the snapshot, and supports `--dry-run`. Veles never
  prunes inline during a ratchet round; its guardrail now points at this helper. Covered by
  `tests/autoresearch/decay-variants.test.sh`.

### Added — three new skills (mined from session history)
- **`mapping-codebase`** — codebase onboarding. Produces a structured `map.md` of an unfamiliar
  repo (orientation, tree, entry points, component boundaries, invocation edges, conventions).
  Design-only; hands off to `/planning-architecture` or `/eliciting-requirements`. Bootstrap:
  `.claude/skills/mapping-codebase/new-map.sh <slug>` → `.tlk/maps/YYYY-MM-DD-<slug>/`.
- **`auditing-consistency`** — cross-corpus drift audit. Sweeps a file set (agents, skills,
  scripts, docs, config) for hardcoded values, contradictions, terminology drift, duplication,
  gaps, and platform pitfalls; emits a ranked, located `audit.md` with a recommended fix per
  finding. Hands fixes to `@cmok`. Bootstrap: `.claude/skills/auditing-consistency/new-audit.sh
  <slug>` → `.tlk/audits/YYYY-MM-DD-<slug>/`. Complements the mechanical
  `shared/audit/tools/lean-claude.sh`.
- **`adapting-patterns`** — external pattern → project fit. Researches a gist/repo/tool, names
  the core insight, separates essential mechanics from incidental context, and designs the
  adaptation as a self-contained carrier (skill/agent/tool). Design-only; hands off to
  `/planning-architecture`. Bootstrap: `.claude/skills/adapting-patterns/new-adaptation.sh
  <slug>` → `.tlk/features/YYYY-MM-DD-adapt-<slug>/`.
- All three are auto-discovered by `init.sh`/`lib.sh` (no registry edits), follow the design-only
  + handoff convention, ship `new-*.sh` bootstraps + templates, and are covered by per-skill
  tests under `tests/skills/`. README and `PIPELINE.md.template` updated (skills tables,
  invocation reference, handoff map).

### Changed — BREAKING: renamed to Talaka
- **The kit is renamed from `agentic-kit` to `Talaka`.** Clean break — there is **no
  automatic migration**; existing installs must be torn down with the old version first
  (steps below). Tag this commit as the first major release (`v1.0.0`). Every user-facing
  and structural name moved:
  - **Brand/display:** `agentic-kit` → **Talaka** (menus, banners, docs).
  - **Submodule directory convention:** `agentic-kit/` → `talaka/`.
  - **Artefacts/state directory:** `.akt/` → `.tlk/` (still overridable with `ARTEFACTS_DIR`).
  - **Config + manifest filenames:** `.agentic-kit.cfg` → `.talaka.cfg`, `.agentic-kit.files` → `.talaka.files`.
  - **Managed-block markers** in `CLAUDE.md`/`AGENTS.md`/`.gitignore`:
    `<!-- agentic-kit:start -->`/`:end` → `<!-- talaka:start -->`/`:end`;
    `# >>> agentic-kit (managed) >>>` → `# >>> talaka (managed) >>>`.
  - **Internal lib API:** `agentic_block_*` / `agentic_gitignore_*` → `talaka_block_*` / `talaka_gitignore_*`;
    `AGENTIC_*` constants → `TALAKA_*`.
  - **Single source of truth:** brand now derives from `KIT_BRAND` / `KIT_SLUG`
    (in `kit.sh` and `shared/lifecycle/tools/lib.sh`) — future rebrands change those two values.

  **Migration for existing installs (do this *before* updating the submodule):**
  1. With the **old** version still checked out, run `teardown.sh` to strip the old `.akt/`,
     config files, and managed blocks from `CLAUDE.md`/`AGENTS.md`/`.gitignore`.
  2. Update the submodule and rename its directory to `talaka/`
     (`git mv agentic-kit talaka` and fix the path in `.gitmodules`), or remove and re-add it.
  3. Re-run `talaka/shared/lifecycle/tools/init.sh`.

### Added
- **curating-knowledge (formerly Belun / Белун) — knowledge-wiki skill** (`skills/curating-knowledge/`). Karpathy's LLM-wiki
  pattern built into the kit: an LLM-owned, interlinked markdown wiki at `wiki/`
  sitting between raw sources and queries so knowledge compounds across sessions.
  Three operations (`/curating-knowledge ingest|query|lint`), three layers (immutable `sources/`,
  LLM-owned `pages/` + `index.md` + `log.md`, project-amendable `SCHEMA.md`), and a
  bootstrap script (`new-wiki.sh`, idempotent). The wiki lives at the **project root**,
  outside the per-developer (git-ignored) `.tlk/` tree — it's committed knowledge,
  kept ≤~100k tokens so direct reading beats retrieval machinery (no vector DB).
  Override its home with `BELUN_WIKI_DIR`. Tests: `tests/skills/curating-knowledge.test.sh`.
- **designing-cli (formerly Zhyzhal / Жыжаль) — CLI-factory skill** (`skills/designing-cli/`). The CLI Printing
  Press methodology as a design-only kit skill: find the API's Non-Obvious Insight,
  absorb competitor table stakes (anti-gaming rule: they're Priority 1), classify the
  domain archetype, and design ~10–15 deep commands with local persistence
  (sync/search/sql) under a hard agent-native contract (typed exit codes 0/2/3/4/5/7,
  `--json`/`--compact`/`--dry-run`/`--stdin`, auto-JSON when piped, bounded output).
  `new-cli.sh <slug>` bootstraps a normal feature folder with `research-brief.md`,
  `design.md`, and `scorecard.md` (two-tier 100-point QA contract; Bagnik gates code
  QA at ≥85 via scorecard → dogfood → proof-of-behaviour → optional read-only live
  smoke test), then hands off to `/planning-architecture`. Tests: `tests/skills/designing-cli.test.sh`.
- **Test suite (`tests/`).** Zero-dependency bash harness (`tests/lib.sh`) + runner
  (`tests/run.sh`) covering the lifecycle layer (`lib.sh` managed blocks, manifest,
  SHA-gated teardown, init↔teardown round-trip), memory (init/promote/rollover/
  search + the new writers), autoresearch (build-eval-set, judge, ratchet incl. the
  invariant guard, mutate-agent guards), and structural lint (frontmatter, the
  no-plugin-dependency invariant, `bash -n`). GitHub Actions matrix
  (`.github/workflows/tests.yml`): ubuntu + macos + windows, plus a no-python job.
  `.gitattributes` pins `*.sh`/`*.py` to LF so Windows checkouts don't corrupt shebangs.
- **Memory writer seams.** `memory/tools/log.sh` (append a validated L2 entry and
  auto-run promote) and `memory/tools/session.sh` (write L1 SESSION-STATE: active
  feature/agent/in-flight decisions) replace the old "hand-edit YAML" prose so the
  memory tree actually fills. `memory/tools/tick.sh` runs promote + rollover for
  schedulers.
- **Single-shot curation** in `memory/tools/promote.sh`: a `confidence: high` L2
  entry promotes to L3 immediately (the schema treats `high` as a rule), instead of
  waiting for the 2-strike rule — which previously left L3/L4/L1 perpetually empty.
- **Opt-in memory maintenance hook.** `memory/tools/memory-hook.sh` installs/removes a
  Claude Code `Stop` hook running `tick.sh`; `init.sh` offers it (`--with-hook` /
  `--no-hook`, prompt otherwise) and `teardown.sh` removes it. `statusline/tools/install-statusline.sh`
  gained a matching `--remove`; teardown now strips both kit entries from
  `.claude/settings.json` (preserving user hooks / a custom statusLine).
- **`kit.sh` "Optional components" submenu.** Multi-level menu to install/remove
  opt-in add-ons (statusline, AutoResearch, memory hook) with live `[installed]`/
  `[off]` status — a new add-on is one registry row. The menu now pauses
  (press-Enter) after an action so output isn't scrolled away by the redraw.
- **README scheduling guide.** Per-OS recipes (Claude hook, cron, launchd, Windows
  Task Scheduler) for `tick.sh`, plus a caveated opt-in section for AutoResearch.

### Changed
- **Skills renamed from mythology to purpose-based gerund names** (aligning with
  Anthropic's skill-authoring naming convention — the `name` + `description` drive
  model selection, so the identifier now states the activity). Mapping:
  `vadavik`→`eliciting-requirements`, `lojma`→`designing-ux`, `cmok`→`creating-mockups`,
  `laznik`→`planning-architecture`, `yaga`→`diagnosing-bugs`, `belun`→`curating-knowledge`,
  `zhyzhal`→`designing-cli`. Invocations change accordingly (`/eliciting-requirements`, …).
  The six **agents keep** their mythology names (`bagnik`, `cmok`, `mokash`, `veles`, `yaga`,
  `zlydni`); this resolves the prior `cmok`/`yaga` skill-vs-agent name collision (the build
  agent is still `@cmok`, the debug agent still `@yaga` with its `debug-*` tooling and `DEBUG:`
  sentinel). **Migration:** re-run `update.sh` to install the new skill dirs; if the old
  `.claude/skills/{vadavik,lojma,cmok,laznik,yaga,belun,zhyzhal}` copies were kit-installed,
  remove them by hand (their names are no longer in the manifest).
- **Top-level `tools/` dissolved into components + `shared/<category>/tools/`.** The flat
  `tools/` grab-bag mixed cross-cutting kit plumbing with feature-specific scripts. It is
  removed; scripts now live in one of two homes, matching the convention `memory/tools/` and
  `autoresearch/tools/` already used:
  - **Components own their tools** — `memory/tools/memory-hook.sh`, and the new
    `statusline/tools/{statusline.sh,statusline.ps1,install-statusline.sh}`.
  - **Cross-cutting tools group by category under `shared/`** —
    `shared/lifecycle/tools/{init,update,teardown,lib,install-helpers}.sh`,
    `shared/project/tools/{validate-config,probe-project,feature-status,bump-version}.sh`,
    `shared/learning/tools/{distill-lessons,apply-patches}.sh`,
    `shared/debug/tools/{debug-log-server.py,debug-log-server.sh,debug-strip.sh}`,
    `shared/deferred/tools/{defer,collect-deferred}.sh`,
    `shared/audit/tools/lean-claude.sh`.

  `lib.sh` now derives the kit root three levels up from its new home, so every sourcing
  script resolves paths unchanged. **No shims** — all references across agents, skills,
  templates, `kit.sh`, docs, and tests were rewritten. Update any direct path references in
  CI or scripts (e.g. `talaka/tools/init.sh` → `talaka/shared/lifecycle/tools/init.sh`);
  installed users heal automatically on the next `update.sh`.
- **Agents and skills now actually write L1 SESSION-STATE.** The `session.sh` writer
  seam existed but nothing called it, so `.tlk/SESSION-STATE.md` sat at the init stub
  forever. Every foreground agent/skill now registers itself as the **active agent**
  on entry (`session.sh agent <name>`); feature originators (Vadavik, Zhyzhal) also
  set the **active feature**; and the decision-making agents (Lojma, Laznik, both
  Cmoks, Yaga, Zhyzhal) **record in-flight decisions** as they go (`session.sh
  decision …`), which Zlydni promotes to L2 and clears at feature close. Background /
  parallel agents (Mokash, Veles) deliberately skip the active-agent write so they
  don't clobber the foreground owner of the singular field. The L1 contract is now
  documented in `templates/memory/SCHEMA.md` ("How agents must use memory").
- **`.gitignore` block now treats the kit as per-developer — it commits nothing.**
  Previously the managed block ignored only an enumerated set of "ephemeral" paths
  and deliberately left `.tlk/PIPELINE.md` + `.tlk/PROJECT.md` tracked so a team
  could share them. But Talaka is a per-developer tool (teammates may not use
  it at all), so committing any of its state imposed it on the repo. The block now
  ignores **all of `.tlk/`** (memory, features, PIPELINE.md, PROJECT.md, bookkeeping)
  plus the **kit-installed `.claude/agents|skills` copies** (enumerated by name so a
  team's own `.claude/` content stays tracked; these are per-developer because Veles
  ratchets them in place). The committed `CLAUDE.md`/`AGENTS.md` include is kept — it
  points at `.tlk/PIPELINE.md`, a harmless no-op for anyone who doesn't run the kit.
  A second kit user just re-runs `init.sh` to regenerate everything locally.
- **Belun's wiki moved from `.tlk/wiki/` to the project root `wiki/`.** With all of
  `.tlk/` now git-ignored, the wiki — which is *meant* to be committed — was relocated
  out of the per-developer tree so it stays tracked. `new-wiki.sh` no longer follows
  `ARTEFACTS_DIR`; override the location with `BELUN_WIKI_DIR` instead.
- **Renamed `talaka.sh` → `kit.sh`.** Shorter and no longer repeats the folder
  name (`talaka/kit.sh`). Same interface — interactive menu and single-action
  dispatch (`kit.sh status`, `--list-json`, `--help`).
- **`.tlk/PROJECT.md` is no longer part of the overwrite prompt.** It is meant to
  diverge from the template, so init/update keep it silently and reset it only with
  `--force`. A new `PROJECT_SHA` in `.talaka.cfg` drives a non-noisy notice when
  the *template* itself changes (new config fields). The conflict prompt's `[d]iff`
  option is now documented.

### Fixed
- **AutoResearch ratchet crashed on every run.** `ratchet.sh` and
  `templates/autoresearch/tools/record-metrics.sh` referenced an undefined
  `$ARTEFACTS_ROOT` under `set -u`, aborting before any scoring. Corrected to
  `$ARTEFACTS`.
- **Standalone `memory/tools/init.sh` failed to seed template stubs.** After
  templates were relocated to the kit-root `templates/memory/`, the script still
  resolved its template dir one level too shallow (`memory/templates/memory`),
  so `cp` aborted under `set -e`. The main `init.sh` swallowed this as a
  non-fatal warning, leaving the memory tree without its `SCHEMA.md` and L3
  stubs. The script now resolves the kit root correctly and seeds all stubs.

### Changed
- **Unified directory-path variable names** in the subpackage scripts. `KIT_DIR`
  previously named three different directories depending on the script's
  location (the kit root in `shared/lifecycle/tools/`, but `autoresearch/` and `memory/` in those
  subpackages). Now `KIT_DIR` always means the kit/submodule root; the
  autoresearch scripts use **`PKG_DIR`** for their own package directory.
  `shared/learning/tools/apply-patches.sh` dropped a redundant local recompute in favour of the
  `SCRIPT_DIR` already provided by `lib.sh`, and `talaka.sh` renamed its
  `ROOT` local to `PROJECT_ROOT` to match the rest of the codebase.
- **Unified artefacts-directory variable names** across all shell entry points.
  The codebase previously used three schemes for two concepts. Now: the public
  override env var is **`ARTEFACTS_DIR`** everywhere (unchanged for the
  memory/autoresearch scripts that already used it); the resolved-path local is
  **`ARTEFACTS`**; the dir-name-only local is **`ARTEFACTS_NAME`**. `lib.sh`,
  `init.sh`, `update.sh`, `teardown.sh`, and `talaka.sh` dropped the old
  `ARTEFACTS_DIR_NAME` / `ART` / `ART_NAME` names.
- **BREAKING (minor):** the `ARTEFACTS_DIR_NAME` environment variable is no
  longer honored. It was only ever read by the `lib.sh`-based tools
  (`init`/`update`/`teardown`/launcher); they now read `ARTEFACTS_DIR` like
  every other script. If you exported `ARTEFACTS_DIR_NAME` to relocate the
  artefacts directory, export `ARTEFACTS_DIR` instead. The `.talaka.cfg`
  key remains `ARTEFACTS_DIR` (unchanged).

### Added
- **Yaga (Яга)** — diagnostic side-loop for hard bugs. Ships as both a skill
  (`/diagnosing-bugs`, hypothesis design) and an agent (`@yaga`, instrument → observe →
  hand-to-Cmok → strip). Includes a single-file Python 3 **debug log server**
  (`shared/debug/tools/debug-log-server.py`, loopback-only HTTP, `/log` `/console` `/network`
  `/tail` `/stream` `/shutdown`, JSONL output), a bash/netcat fallback
  (`shared/debug/tools/debug-log-server.sh`), a sentinel-based strip helper
  (`shared/debug/tools/debug-strip.sh`), paste-ready probe snippets for JS/TS, Python, Bash,
  Go, and Java/Kotlin, plus a browser bootstrap that hooks `console.*`,
  `window.onerror`, `unhandledrejection`, `fetch`, and `XMLHttpRequest`.
  Investigations live in `.tlk/debug/YYYY-MM-DD-<slug>/` and archive to
  `.tlk/archive/debug/<slug>/`. Cmok and Bagnik now suggest `@yaga` when the
  same bug recurs or the gate fails twice for non-obvious reasons. Pipeline
  template documents Yaga as a side-loop that splices into the main flow only
  when invoked.

### Removed (BREAKING)
- **`--ide=` flag** and all Cursor / GitHub Copilot generation. Previously
  `init.sh`, `update.sh`, and `teardown.sh` produced and managed three parallel
  install trees (`.claude/`, `.cursor/`, `.github/`). The kit now installs
  **one** Claude-shaped layout. Cursor, GitHub Copilot, Codex, and other
  workspace-aware tools read `AGENTS.md` — the kit writes it alongside
  `CLAUDE.md` with the same managed include block. `init.sh` rejects
  `--ide=*` with exit code 2 and a message pointing at this CHANGELOG.
- **`cursor_rule_name` / `cursor_subagent_name`** YAML keys on agent and skill
  files, and the **`cmok-build`** subagent shim that worked around Cursor's
  namespace clash between the `cmok` skill and `cmok` agent. The build agent
  is just `@cmok` again everywhere.
- `shared/lifecycle/tools/init.sh` lost ~500 lines of Cursor/Copilot helpers
  (`cursor_subagent_*`, `write_cursor_subagent`, `setup_cursor`,
  `write_github_agent`, `write_github_instructions`, `setup_github`,
  `extract_yaml_field`, `escape_yaml_double`, `strip_frontmatter_body`,
  `yaml_truthy_is_background`, and the interactive IDE picker).

### Migration

Run `talaka/shared/lifecycle/tools/update.sh` once. It refreshes the pipeline, agents,
and skills the same way it always has, then sweeps the legacy `.cursor/` and
`.github/` trees. If you edited any of those files locally, they are
preserved with a `[skipped: locally modified]` warning — remove them
manually if no longer needed.

### Added
- **`talaka.sh`** — single stage-aware interactive launcher. Detects install
  state (not installed / needs config / ready) and only offers actions that fit.
  Supports `<action>` positional argument for non-interactive / CI use,
  `--list-json` for machine-readable action registry, and `--help`.
- **`update.sh --help`** and **`teardown.sh --help`** — every top-level entry
  point now prints its own usage instead of falling through to `init.sh`.
- **`teardown.sh`** now accepts `--non-interactive` / `-n` as aliases for
  `--yes` / `-y`, matching `init.sh`'s flag conventions.
- `.github/workflows/shellcheck.yml` — CI lints all shell scripts on push/PR.
- `.shellcheckrc` — repo-level lint configuration with reasoned exclusions.
- `CHANGELOG.md` — this file.
- `shared/project/tools/bump-version.sh` — rejects non-semver versions (`X.Y.Z`, integers only)
  before bumping; previously a malformed `version` field could produce nonsense
  like `1.20.-1`.

### Changed
- `init.sh` — installs both `CLAUDE.md` and `AGENTS.md` with the same managed
  include block. The `talaka_block_*` lib helpers no longer take an
  `ide_label` argument (the embedded comment names talaka instead).
- `update.sh` — automatically sweeps legacy `.cursor/agents/`,
  `.cursor/skills/`, `.cursor/rules/`, `.github/agents/`,
  `.github/instructions/`, and the managed block in
  `.github/copilot-instructions.md` after each refresh. Manifest-SHA safety
  is preserved: only files the kit installed and the user did not edit are
  removed; locally-edited files are skipped with a warning.
- `teardown.sh` — consolidated the old Cursor and GitHub Copilot teardown
  sections into a single "Legacy IDE artefacts" sweep, using the same
  manifest predicate. The dedicated sections were renumbered.
- `shared/lifecycle/tools/lib.sh` — gained `kit_managed_file_remove`, `kit_managed_tree_remove`,
  `kit_include_block_remove`, `kit_rm`, `kit_rm_rf`, `_manifest_drop`
  (lifted from `teardown.sh` so `update.sh` can use them). The last two
  manifest-mismatch branches in the file/tree removers now `return 1` so
  callers can count "skipped" vs "removed" accurately.
- `init.sh` — silent `|| true` after `probe-project.sh` and `memory-init.sh`
  replaced with explicit `warn` messages so failures are audible without
  aborting the install.
- README.md — promoted `talaka.sh` to primary human entry point in
  Quick start; reordered lifecycle scripts table; documented Windows /
  MSYS2 / bash >= 4.0 requirement.

### Security
- `talaka.sh` teardown handler — user-supplied `extra args` are now
  word-split into a bash array and passed as `"${teardown_args[@]}"` instead
  of an unquoted `$extra` expansion. Closes a `; rm -rf …` injection vector
  that required a TTY-typed input but was unsafe in principle.

### Removed
- `kit-menu.sh` (untracked draft) — superseded by `talaka.sh`.
- `init.sh`, `update.sh`, `teardown.sh` moved from kit root to `shared/lifecycle/tools/`
  (`talaka/shared/lifecycle/tools/init.sh`, `shared/lifecycle/tools/update.sh`, `shared/lifecycle/tools/teardown.sh`). No shims
  provided; update any direct path references in CI or scripts.

## Earlier history

Pre-CHANGELOG history is in `git log`. Notable structural moves:

- `lib.sh` -> `tools/lib.sh`
- `PIPELINE.md.template` / `PROJECT.md.template` -> `templates/`
- Mokash agent added (documentation role)
- Memory layered tree (`SCHEMA.md`, L1-L4) introduced
- `.tlk/` adopted as the single home for kit-managed project state
