---
name: designing-cli
description: CLI factory — design an agent-native CLI for any API (printing-press pattern). Finds the API's non-obvious value, absorbs the feature set of every competing tool, designs a deep command surface with local persistence, and writes the 100-point scorecard the build is gated on. Hand off to /planning-architecture for the build pipeline.
disable-model-invocation: false
---

# Designing CLIs — CLI Factory (skill)

Given an API, you don't stamp out a thin wrapper — you find what the API is *secretly* good for, absorb every feature the ecosystem already shipped, and design the CLI a power user (human or agent) would actually reach for. The pattern is mvanhorn's CLI Printing Press: *every API has a secret identity — find it, absorb every competing tool, then build the GOAT CLI.*

This skill is **design-only**, like the kit's other skills: it produces the research brief, the design, and the scorecard contract, then hands the build to the normal pipeline (`/planning-architecture` → `@bagnik` → `@cmok`). The artifacts carry the methodology into the feature folder so downstream agents enforce it without re-reading this file.

## When to Use

- `/designing-cli <api-name>` — research from public spec/docs.
- `/designing-cli <openapi.json | api.har>` — design from a provided spec or captured traffic.
- `/designing-cli <base-url>` — no spec exists; reverse-engineer from docs pages and observed traffic.

## Bootstrap

```bash
.claude/skills/designing-cli/new-cli.sh <api-slug>
```

Creates `.tlk/features/YYYY-MM-DD-cli-<api-slug>/` with `research-brief.md`, `design.md`, `scorecard.md`, and `handoff-log.md` templates. The CLI is a feature like any other — same folder conventions, same handoff log, same archive path.

You originate the feature, so set the L1 hot state once the folder exists:

```bash
talaka/memory/tools/session.sh feature cli-<api-slug>
talaka/memory/tools/session.sh agent designing-cli
```

## Phase 0 — Resolve the input

Establish the API surface from the best available evidence, in preference order: official OpenAPI spec → published docs → HAR / captured traffic → probing. Record in `research-brief.md` **where the spec came from and how trustworthy it is** — every downstream verification compares against this. Also pin down the auth model (key, OAuth, cookie) and rate-limit behaviour now, not during the build.

## Phase 1 — Research brief

Fill `research-brief.md`:

1. **Non-Obvious Insight (NOI).** One sentence naming the hidden value beyond the API's marketed purpose (the canonical example: Discord isn't chat — it's a searchable knowledge base; every thread is institutional memory). The NOI drives feature prioritisation; a brief without one is a wrapper spec.
2. **Ecosystem absorption.** Catalog every competing CLI/tool/SDK for this API and the features users actually praise. Competitor table stakes are **Priority 1** in the design — absorbing them is mandatory, not optional (this is the anti-gaming rule: you may not skip hard table-stakes work to chase easy scorecard points).
3. **Domain archetype.** Classify the API; the archetype seeds the insight commands:

| Archetype | Signals | Insight commands to consider |
|-----------|---------|------------------------------|
| Project management | issues, tasks, assignees | `stale`, `orphans`, `load`, `health` |
| Communication | messages, channels, threads | `channel-health`, `message-stats` |
| Payments | charges, invoices, amounts | `reconcile`, `revenue`, `health` |
| Infrastructure | servers, deployments | `health`, `similar` |
| Content | documents, pages, blocks | `health`, `similar` |

4. **High-gravity resources.** The 1–3 resource types users return to constantly — these get real local persistence; everything else gets pass-through.

## Phase 2 — Design

Fill `design.md`:

- **Depth over breadth.** The ~10–15 commands power users need, not a wrapper per endpoint. An API with 300 endpoints and 11 great commands beats 300 mediocre ones. Justify each command's rung on the creativity ladder: (1) endpoint wrapper → (2) formatting & ergonomics → (3) local persistence & offline search → (4) domain analytics → (5) behavioural insight. A design stuck at rungs 1–2 is not done.
- **Data layer.** High-gravity resources get domain-specific local tables (SQLite where the stack allows, with FTS for text) — not JSON blobs. Standard trio: `sync` (incremental pull, cursor tracking, idempotent upserts), `search` (millisecond local full-text), `sql`/`query` (raw store access for power users). Compound insight commands read the local store, never hammer the API.
- **Agent-native contract.** Copy into `design.md` as acceptance criteria — these are hard rules, not suggestions:

| Rule | Contract |
|------|----------|
| Typed exit codes | `0` success, `2` usage error, `3` not found, `4` auth, `5` API error, `7` rate-limited. Agents branch on codes, never parse error prose. |
| Output modes | `--json` everywhere; **auto-JSON when stdout is not a TTY** (no flag needed in pipes); `--compact` returns only high-gravity fields (60–80% fewer tokens). |
| Safe exploration | `--dry-run` on every mutating command; `--stdin` for bulk input. |
| Bounded output | Default limits with an explicit continuation hint: `Showing N results. To narrow: add --limit or filter flags.` |
| Errors are actionable | Auth failure says which env var / config key to set; rate limit says when to retry. |

- **Language.** Default to the project's stack (`.tlk/PROJECT.md`); for a standalone tool, Go + Cobra is the reference (single static binary — the friendliest install for agents). Record the choice and why.

## Phase 3 — Handoff to the pipeline

The build is **not** yours. Append to `handoff-log.md` and hand off to `/planning-architecture` (architecture + tests), citing all three artifacts. From there the normal flow applies: planning-architecture → `@bagnik` (test gate) → `@cmok` (build) → `@bagnik` (code QA, **scorecard-gated**) → `@zlydni`.

`scorecard.md` is the QA contract: two tiers, 100 points, **Grade A (≥85) required to ship**. Tier 1 scores the agent-native infrastructure; Tier 2 scores domain correctness (paths valid against the spec, auth protocol fidelity, sync→upsert→search pipeline actually flows, no dead flags). Bagnik scores it during code QA and blocks below 85. Verification is mechanical, in layers: scorecard → dogfood (run every command; dead flags, invalid paths, auth mismatches) → proof-of-behaviour (write through the pipeline, read it back) → optional **read-only** live smoke test.

## Guardrails

- **No build.** You produce designs and contracts; `@cmok` builds. Don't scaffold code beyond illustrative snippets in `design.md`.
- **No NOI, no design.** If you cannot articulate the non-obvious insight, say so and ask the user whether a plain wrapper is genuinely what they want.
- **Anti-gaming.** Ecosystem table stakes are Priority 1; scorecard optimisation is last. Never trade a competitor-parity feature for scorecard points.
- **Live API calls during design are read-only**, rate-limit-respecting, and recorded in the brief (endpoints touched, when, what was observed).
- **Secrets stay out of artifacts.** Reference env var names, never values.

## Memory

Read `.tlk/MEMORY.md` (L4) first — prior CLI features may have settled stack, auth-storage, or distribution decisions; don't relitigate them. When the design lands a durable decision (store schema, exit-code extension, language choice), log it: `talaka/memory/tools/log.sh --type decision "<the decision>"`.

Record design decisions in L1 as you make them: `talaka/memory/tools/session.sh decision "Chose X over Y because …"` — these accumulate in the hot state and Zlydni promotes them to L2 when the CLI feature is committed.
