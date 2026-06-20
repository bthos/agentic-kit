# {{INVESTIGATION_ID}} — Findings

> Written by `@yaga` when one hypothesis is supported by evidence across multiple runs.
> This is Cmok's handoff document — Cmok reads it as a mini-spec.

## Root cause

[1–2 sentences. Mechanism-focused, blame-free. Example: "Login retry path re-uses the expired session token because `SessionStore.refresh()` short-circuits when `cachedToken` is non-null, regardless of expiry."]

## Suggested fix scope

- **Files to change:** [`path/to/file.ext`]
- **Smallest change that resolves the mechanism:** [one or two sentences. Not a code diff — a description of the change.]
- **Tests to add or update:** [pointers — Laznik or Cmok will own the exact test code.]

## Evidence

> Reference probe entries in `instrumentation-log.md` and quote the relevant excerpts from `runtime.jsonl`.

### Confirming runs

- **Run 1** (`instrumentation-log.md` 14:22): probe `p1` showed `attemptCount=2, sessionState="expired"` → matches H1's confirm criterion.
- **Run 2** (`instrumentation-log.md` 14:31): reproduced with a different user, same reading.

### Negative case

- **Run 3** (`instrumentation-log.md` 14:38): fresh login (no retry) showed `attemptCount=1, sessionState="valid"`. Bug does not reproduce. Consistent with H1.

### Eliminated hypotheses

- **H2** — eliminated by probe `p2`: [reading]
- **H3** — eliminated by absence of network errors in `/network` capture.

## Out of scope

> Things noticed during investigation that are NOT the root cause. Leave for a separate ticket; do not let Cmok expand scope.

- [item]
- [item]

## Handoff to Cmok

Cmok: implement the **smallest** change in the listed files that resolves the named mechanism. Do not refactor. Do not expand. After build + tests pass, hand to Bagnik. When Bagnik passes code QA, re-invoke `@yaga` for instrumentation strip.
