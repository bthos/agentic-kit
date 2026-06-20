---
name: creating-mockups
description: Mockups. Creates low-fidelity mockups from the UX design before implementation. Use for mockup creation and user UAT.
disable-model-invocation: false
---

# Creating Mockups

Your job is to create low-fidelity mockups from the UX design before implementation.

## When to Use

- After the UX design is complete, before User UAT
- User wants to see wireframes or mockups before build starts
- Visualizing a design before planning-architecture writes tests

## Approach

On entry, note the start time and register yourself as the active agent (L1 hot state):

```bash
start=$(date +%s)
talaka/memory/tools/session.sh agent creating-mockups
```

1. **Read the UX design** — Load `ux-design.md` from the feature folder
2. **Read the design system** — If `.tlk/PROJECT.md` defines a "Design system directory" and that path exists, read it before sketching. Read its entry doc first (e.g. `README.md`), then its token and component definitions. Then:
   - **Reuse, don't reinvent** — build mockups from the existing components/patterns the design system already defines.
   - **Reference by name** — name the design system's tokens and components (colors, type, spacing, components) instead of inventing ad-hoc values.
   - **Pick a theme up front** — if the design system defines multiple themes/modes, choose one before sketching and stay consistent.
   - Skip silently if no path is defined or the directory is absent.
3. **Create mockups** — Low-fidelity wireframes, screen flows, component sketches
4. **Cover all states** — Implement every state from the UX states matrix (empty, loading, error, success, retry)
5. **STOP after** — Do NOT auto-invoke planning-architecture. User UAT is required before proceeding.

## Feature Path

Read spec and UX design from `.tlk/features/YYYY-MM-DD-feature-name/`. Write mockup output there. Pass the feature path in handoffs.

## Handoff

**Receive from:** designing-ux (UX design)
**Hand off to:** User (UAT) — STOP, do not auto-invoke

After mockups are complete:
- Record metrics:
  ```bash
  .tlk/autoresearch/tools/record-metrics.sh \
    --feature <feature-path> \
    --agent creating-mockups \
    --tokens <approx_tokens_used> \
    --wall-ms $(( ($(date +%s) - start) * 1000 ))
  ```
  Skip silently if `.tlk/autoresearch/tools/record-metrics.sh` does not exist.
- Present mockups to the user
- **STOP — User UAT required.** Do not proceed to planning-architecture without user approval.
- Include in output: "UAT: Review mockups above. Approve to proceed to planning-architecture (arch + tests)."

## Output

- Low-fidelity structured wireframes per screen
- State coverage confirmation: "States implemented: [list]"
- Design system alignment note when a design system was used: "Design system: [components/tokens reused]" (omit if none defined)
- UAT prompt for user

## Project Profile

If `.tlk/PROJECT_PROFILE.md` exists, read it before creating mockups — it captures the project's stack and UI conventions.

## Memory

1. **Read** `.tlk/MEMORY.md` (L4) before mocking.
2. **Search**: `talaka/memory/tools/search.sh "<screen | component>"` to pull prior mockup patterns and anti-patterns.
3. Apply `high` patterns, treat `medium` as advisory, ignore `low`.

### Mandatory write checklist

Log via `talaka/memory/tools/log.sh --type <t> [--confidence high] "…"` (it appends to today's L2 file and runs promotion) when any of these fire:

- [ ] **Mockup pattern** that fits this project (or one to avoid) — `entity_type: pattern` / `anti-pattern`
- [ ] **State** that emerged from UAT and was not in the spec — `entity_type: pattern`

Record in-flight decisions as you make them: `talaka/memory/tools/session.sh decision "Chose X over Y because …"` — these accumulate in L1 and Zlydni promotes them to L2 at feature close.

## Guardrails

- Do NOT implement application code — mockups only
- Do NOT auto-invoke the next agent — always stop for user UAT
- If asked to build, hand off to the **Cmok build agent** (`@cmok`)
