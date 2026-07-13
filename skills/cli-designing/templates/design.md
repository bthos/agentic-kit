# {{SLUG}} — CLI Design

_Filled by /cli-designing (Phase 2). The agent-native contract below is acceptance criteria for Bagnik's code QA — hard rules, not suggestions._

## Identity

- **Binary name:** `{{SLUG}}`
- **Language / framework:** [from .tlk/PROJECT.md, or Go + Cobra for standalone; why]
- **One-liner:** [what this CLI is, restated through the NOI]

## Command surface

_Depth over breadth: ~10–15 commands that matter, each justified by its rung on the creativity ladder (1 wrapper → 2 ergonomics → 3 local persistence/search → 4 domain analytics → 5 behavioural insight). A surface stuck at rungs 1–2 is not done._

| Command | Rung | Priority | What it does / why a power user reaches for it |
|---------|------|----------|------------------------------------------------|
| | | P1 (table stake) | |

## Data layer

_High-gravity resources get domain-specific local tables (SQLite + FTS where the stack allows) — not JSON blobs._

- **Store:** [e.g. SQLite at ~/.config/{{SLUG}}/data.db]
- **Tables:** [resource → columns; FTS index over which text fields]
- **`sync`:** [incremental pull — cursor/updated-since strategy, idempotent upserts]
- **`search`:** [local FTS query shape]
- **`sql` / `query`:** [raw store access for power users]
- Compound insight commands read the local store, never hammer the API.

## Agent-native contract (acceptance criteria)

- [ ] Typed exit codes: `0` success, `2` usage, `3` not found, `4` auth, `5` API error, `7` rate-limited — agents branch on codes, never parse error prose
- [ ] `--json` on every command; **auto-JSON when stdout is not a TTY**
- [ ] `--compact` returns only high-gravity fields (60–80% fewer tokens)
- [ ] `--dry-run` on every mutating command
- [ ] `--stdin` for bulk input
- [ ] Bounded output with continuation hint: `Showing N results. To narrow: add --limit or filter flags.`
- [ ] Errors are actionable (auth error names the env var; rate limit names the retry-after)
- [ ] No secrets in output, logs, or store

## Auth & config

- **Credential source:** [env var name(s); config file path]
- **`auth doctor`-style check:** [how a user/agent verifies credentials without a mutation]

## Open questions

- [ ] [anything architecture-planning must settle before tests are written]
