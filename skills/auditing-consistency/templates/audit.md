# {{AUDIT_ID}} — Consistency Audit

_Filled by /auditing-consistency. Read by @cmok, who applies the fixes. Every finding cites **every** location and names the **single source of truth** the corpus should converge on._

## Scope

- **Corpus audited:** [globs/dirs — e.g. `agents/*.md`, `skills/*/SKILL.md`, `*/tools/*.sh`, `templates/*`]
- **As of:** commit `[short-sha]` ({{DATE}})
- **Dimensions checked:** [tick the ones run below]

## Dimensions checklist

- [ ] **Hardcoded values** that should reference one variable / config key / single source of truth.
- [ ] **Contradictions** — two files instruct opposite things.
- [ ] **Terminology drift** — one concept named differently across files (e.g. a model's name vs a pinned version).
- [ ] **Duplication** — the same instruction copied where copies can silently diverge.
- [ ] **Gaps** — a referenced file / flag / command / counterpart that does not exist.
- [ ] **Platform pitfalls** — shell/OS hazards repeated inconsistently (e.g. long command lines that should route through a temp file).

## Findings

> Ranked by severity. **Severity:** `high` = will produce wrong behaviour or contradictory instructions · `med` = drift that will bite on the next change · `low` = cosmetic / stylistic. Each finding names a single canonical source the rest should converge on.

### F1 — [short label] · severity: [high|med|low] · [dimension]

- **What:** [the inconsistency, in one line]
- **Locations:** every instance —
  - `path/to/a.ext:line` — [current value/wording]
  - `path/to/b.ext:line` — [current value/wording]
- **Canonical source:** [the one place that should be authoritative, and why]
- **Recommended fix:** [concrete change @cmok applies — e.g. "replace literals with `$ARTEFACTS_DIR`", "delete the copy in b, link to a"]

### F2 — …

## Summary

| Severity | Count |
|----------|-------|
| high | |
| med | |
| low | |

## Evidence

_Commands run to collect locations (so the audit is reproducible)._

- `[grep/rg invocation]` → [what it surfaced]
