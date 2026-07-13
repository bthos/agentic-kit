# {{SLUG}} — Verification Scorecard

_The QA contract for this CLI. Scored by Bagnik during code QA; **Grade A (≥85/100) required to ship** — below 85, Bagnik blocks and hands back to Cmok. Score honestly; the anti-gaming rule applies (table stakes in design.md are Priority 1 — points here are earned by building them, not instead of them)._

## Tier 1 — Agent-native infrastructure (50 pts)

| Check | Max | Score | Evidence |
|-------|-----|-------|----------|
| Output modes: `--json` everywhere, auto-JSON when piped, `--compact` trims to high-gravity fields | 10 | | |
| Typed exit codes (0/2/3/4/5/7) used consistently; no error-prose-only failures | 10 | | |
| Auth: credential discovery, actionable auth errors, doctor-style check | 10 | | |
| Safe exploration: `--dry-run` on every mutation, `--stdin` bulk input | 10 | | |
| Terminal UX: bounded output + continuation hint, helpful `--help`, sensible defaults | 5 | | |
| Local store hygiene: store location, schema migrations, cache invalidation | 5 | | |

**Tier 1 subtotal: /50**

## Tier 2 — Domain correctness (50 pts)

| Check | Max | Score | Evidence |
|-------|-----|-------|----------|
| Path validity: every command's endpoint exists in the spec (per research-brief provenance) | 15 | | |
| Data pipeline: `sync` → upsert → `search` flows end-to-end; FTS returns synced content | 15 | | |
| Auth protocol fidelity: headers/flow match the spec exactly | 10 | | |
| Type accuracy + dead-code elimination: response fields typed correctly; no dead flags or unreachable commands | 10 | | |

**Tier 2 subtotal: /50**

## Total: /100 — Grade: [A ≥85 | B 70–84 | C <70]

## Verification layers (all four before sign-off)

- [ ] **Scorecard** — tables above filled with evidence, not assertions
- [ ] **Dogfood** — every command executed at least once; dead flags, invalid paths, auth mismatches recorded
- [ ] **Proof of behaviour** — write through the pipeline, read it back (e.g. `sync` then `search` finds a known record)
- [ ] **Live smoke test** (optional, user-authorised) — **read-only** calls against the real API; respects rate limits

## Findings / regen-merge notes

_Bagnik appends failures here; Cmok fixes targeted items and re-submits — iterate until ≥85, no iteration limit._
