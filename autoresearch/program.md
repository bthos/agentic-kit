# AutoResearch Program — Правь

Read by **Veles** (`agents/veles.md`) before every ratchet round. Anything declared here is **invariant**: Veles cannot change it as part of a mutation. To rewrite this file, edit it manually with full intent — Veles will detect the hash change and abort the round if it happens mid-loop.

## Composite metric

```
composite = accuracy_score − λ · cost_normalized
λ = 0.3
```

- **accuracy_score ∈ [0, 1]** — fraction of acceptance criteria from `eval-set/*.md` that LLM-as-judge marks as satisfied. Computed by `tools/judge.sh`.
- **cost_normalized ∈ [0, 1]** — `(wall_clock_seconds × $/min + tokens × $/token)` for the run, divided by the 95th-percentile of the last 50 recorded runs in `runs/cost.jsonl`. Capped at 1.0.

`λ = 0.3` means accuracy is the primary objective; cost is penalised but never dominates. Tweak only with deliberate intent — most teams should leave it alone.

## Invariants (Veles MUST NOT violate)

1. **Tests are sacred.** Never delete or simplify tests anywhere in the project (`tests/`, `__tests__/`, `*_test.*`, `*.spec.*`, `*.test.*`, etc.). Never alter test assertions to make them pass.
2. **Acceptance criteria are sacred.** Never edit `eval-set/*.md`. Never lower the bar of any acceptance criterion in archived `spec.md` files referenced by the eval-set.
3. **The judge is sacred.** Never edit `judge.md` to make scoring looser. Veles hashes `judge.md` at round start and end; mismatch = abort round.
4. **Eval-set is read-only for Veles.** New eval pairs are added by humans or by `tools/build-eval-set.sh` (which only adds, never edits or removes).
5. **No network mutations.** Veles never runs `git push`, `gh pr create`, package publish commands, deployment commands, or anything that affects systems beyond the project root.
6. **No `rm -rf`.** Veles only modifies installed agent/skill copies and writes to `agentic-kit/autoresearch/`.
7. **Manifest integrity.** After every accepted mutation, `.artefacts/.agentic-kit.files` must record the new SHA-256 for the changed file. `teardown.sh` must still recognise the file as kit-managed.

## Allowed mutation targets

Veles may modify:

- **Installed agent prompts** — `.claude/agents/<agent>.md`, `.cursor/agents/<agent>.md`, `.github/agents/<agent>.agent.md` (these are copies; manifest hash gets refreshed on accept).
- **Installed skill prompts** — `.claude/skills/<skill>/SKILL.md`, `.cursor/skills/<skill>/SKILL.md`, `.github/instructions/<skill>.instructions.md`.
- **Front-matter `model:` field** — swap `sonnet` ↔ `haiku` ↔ `opus` when justified by composite.
- **Task decomposition rules** within agent prompts (e.g. "split into N steps when …").
- **Tool-call ordering hints** within agent prompts.

Veles may **NOT** modify:

- The kit source under `agentic-kit/` (only the user does that, via PRs).
- `.cursor/agents/` files generated **from** `agents/*.md` if the change would also need to land in the kit source — those should be proposed via `distill-lessons.sh --target=agents` instead.
- `PROJECT.md`, `CLAUDE.md`, `AGENTS.md`, `templates/PIPELINE.md.template`, `templates/PROJECT.md.template`.
- `program.md`, `judge.md`, `eval-set/`.

## Stop conditions

Veles stops a session when **any** of the following hold:

- `--rounds=N` budget is exhausted.
- Three consecutive rejections (signals local optimum or noise dominating).
- Any invariant check fails mid-round (abort and report).
- User interrupt.

## Logging

Every round appends to `runs/`:

- **`runs/cost.jsonl`** — one row per evaluated run: `{ts, run_id, file, variant, tokens, wall_ms, cost_usd, accuracy, composite}`.
- **`runs/ratchet.jsonl`** — one row per accepted mutation: `{ts, round, file, baseline_composite, proposal_composite, delta, rationale}`.
- **`runs/rejected.jsonl`** — one row per rejected mutation: `{ts, round, file, baseline_composite, proposal_composite, reason}`.

Rows are JSON Lines so `jq` can compute trends easily.
