# Changelog

All notable changes to **agentic-kit** are documented here. The kit is consumed
as a git submodule, so downstream projects pin a specific commit — this log is
how you tell which behaviors changed between pinned revisions.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to a loose semantic-versioning intent (no formal version
tags yet — entries are dated and grouped by submodule HEAD).

## [Unreleased]

### Added
- **Yaga (Яга)** — diagnostic side-loop for hard bugs. Ships as both a skill
  (`/yaga`, hypothesis design) and an agent (`@yaga`, instrument → observe →
  hand-to-Cmok → strip). Includes a single-file Python 3 **Yaga log server**
  (`tools/yaga-log-server.py`, loopback-only HTTP, `/log` `/console` `/network`
  `/tail` `/stream` `/shutdown`, JSONL output), a bash/netcat fallback
  (`tools/yaga-log-server.sh`), a sentinel-based strip helper
  (`tools/yaga-strip.sh`), paste-ready probe snippets for JS/TS, Python, Bash,
  Go, and Java/Kotlin, plus a browser bootstrap that hooks `console.*`,
  `window.onerror`, `unhandledrejection`, `fetch`, and `XMLHttpRequest`.
  Investigations live in `.akt/debug/YYYY-MM-DD-<slug>/` and archive to
  `.akt/archive/debug/<slug>/`. Cmok and Bagnik now suggest `@yaga` when the
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
- `tools/init.sh` lost ~500 lines of Cursor/Copilot helpers
  (`cursor_subagent_*`, `write_cursor_subagent`, `setup_cursor`,
  `write_github_agent`, `write_github_instructions`, `setup_github`,
  `extract_yaml_field`, `escape_yaml_double`, `strip_frontmatter_body`,
  `yaml_truthy_is_background`, and the interactive IDE picker).

### Migration

Run `agentic-kit/tools/update.sh` once. It refreshes the pipeline, agents,
and skills the same way it always has, then sweeps the legacy `.cursor/` and
`.github/` trees. If you edited any of those files locally, they are
preserved with a `[skipped: locally modified]` warning — remove them
manually if no longer needed.

### Added
- **`agentic-kit.sh`** — single stage-aware interactive launcher. Detects install
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
- `tools/bump-version.sh` — rejects non-semver versions (`X.Y.Z`, integers only)
  before bumping; previously a malformed `version` field could produce nonsense
  like `1.20.-1`.

### Changed
- `init.sh` — installs both `CLAUDE.md` and `AGENTS.md` with the same managed
  include block. The `agentic_block_*` lib helpers no longer take an
  `ide_label` argument (the embedded comment names agentic-kit instead).
- `update.sh` — automatically sweeps legacy `.cursor/agents/`,
  `.cursor/skills/`, `.cursor/rules/`, `.github/agents/`,
  `.github/instructions/`, and the managed block in
  `.github/copilot-instructions.md` after each refresh. Manifest-SHA safety
  is preserved: only files the kit installed and the user did not edit are
  removed; locally-edited files are skipped with a warning.
- `teardown.sh` — consolidated the old Cursor and GitHub Copilot teardown
  sections into a single "Legacy IDE artefacts" sweep, using the same
  manifest predicate. The dedicated sections were renumbered.
- `tools/lib.sh` — gained `kit_managed_file_remove`, `kit_managed_tree_remove`,
  `kit_include_block_remove`, `kit_rm`, `kit_rm_rf`, `_manifest_drop`
  (lifted from `teardown.sh` so `update.sh` can use them). The last two
  manifest-mismatch branches in the file/tree removers now `return 1` so
  callers can count "skipped" vs "removed" accurately.
- `init.sh` — silent `|| true` after `probe-project.sh` and `memory-init.sh`
  replaced with explicit `warn` messages so failures are audible without
  aborting the install.
- README.md — promoted `agentic-kit.sh` to primary human entry point in
  Quick start; reordered lifecycle scripts table; documented Windows /
  MSYS2 / bash >= 4.0 requirement.

### Security
- `agentic-kit.sh` teardown handler — user-supplied `extra args` are now
  word-split into a bash array and passed as `"${teardown_args[@]}"` instead
  of an unquoted `$extra` expansion. Closes a `; rm -rf …` injection vector
  that required a TTY-typed input but was unsafe in principle.

### Removed
- `kit-menu.sh` (untracked draft) — superseded by `agentic-kit.sh`.
- `init.sh`, `update.sh`, `teardown.sh` moved from kit root to `tools/`
  (`agentic-kit/tools/init.sh`, `tools/update.sh`, `tools/teardown.sh`). No shims
  provided; update any direct path references in CI or scripts.

## Earlier history

Pre-CHANGELOG history is in `git log`. Notable structural moves:

- `lib.sh` -> `tools/lib.sh`
- `PIPELINE.md.template` / `PROJECT.md.template` -> `templates/`
- Mokash agent added (documentation role)
- Memory layered tree (`SCHEMA.md`, L1-L4) introduced
- `.akt/` adopted as the single home for kit-managed project state
