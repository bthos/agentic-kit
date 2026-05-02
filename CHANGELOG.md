# Changelog

All notable changes to **agentic-kit** are documented here. The kit is consumed
as a git submodule, so downstream projects pin a specific commit — this log is
how you tell which behaviors changed between pinned revisions.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to a loose semantic-versioning intent (no formal version
tags yet — entries are dated and grouped by submodule HEAD).

## [Unreleased]

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
- `init.sh:200` — `--ide` validation error message now lists `both` (the
  alias for `all` that was already accepted by the regex).
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
- `.agentic-kit-artefacts/` adopted as the single home for kit-managed project state
