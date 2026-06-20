# {{INVESTIGATION_ID}} — Hypothesis

## Bug statement

[One paragraph. What goes wrong, what was expected, reproduction steps, frequency. Quote the exact error message if any.]

## Environment

- **Stack:** [language, framework, version]
- **Runtime:** [local dev / staging / prod]
- **Recently changed:** [files touched in the last N commits that touch the suspect code path]

## Ranked hypotheses

> Most likely first. Each hypothesis is **mechanistic** (names a cause, not a symptom), **falsifiable**, and **bounded** (names files/functions).

### H1 — [short label, e.g. "stale cache on retry"]

- **Mechanism:** [what is happening that produces the symptom]
- **Bounded to:** [`path/to/file.ext`, function or call site]
- **Why likely:** [one line — recent change, smell in code, prior incident]
- **Probe (confirm):** [what reading would prove this]
- **Probe (eliminate):** [what reading would disprove this]

### H2 — …

### H3 — …

## Instrumentation plan

> One row per probe. Keep the set minimal — probes that fire on every path tell you nothing.

| ID | File:line | Captures | Confirms | Eliminates |
|----|-----------|----------|----------|------------|
| p1 | `path/to/file.ext:42` | `userId, sessionState, attemptCount` | H1 if `attemptCount > 1 && sessionState == "expired"` | H1 if `sessionState == "valid"` |
| p2 | … | … | … | … |

## Success criteria

The investigation succeeds when **one** hypothesis is supported by evidence across multiple runs (including at least one negative case where the bug does not reproduce). Then `@yaga` writes `findings.md` and hands off to Cmok.

## Notes

- Investigation id: `{{INVESTIGATION_ID}}` — use this as the sentinel: `YAGA:{{INVESTIGATION_ID}}`.
- Probes are added by `@yaga` (agent). This skill does not edit code.
