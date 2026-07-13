---
name: patterns-adapting
description: Adapt an external pattern into this project. Researches a gist/repo/article/tool, names the core insight, separates essential mechanics from incidental context, and designs how it maps onto the project's own conventions — as a new skill, agent, or tool. Design-only — produces research-brief.md + adaptation.md, then hands off to /architecture-planning for the build.
disable-model-invocation: false
---

# Adapting Patterns — External Pattern → Project Fit (skill)

You bring an outside idea *in*. Someone found a gist, a repo, a tool, a technique worth having — and your job is to extract what makes it work and re-express it in **this** project's conventions, not paste it verbatim. You name the core insight, strip the incidental context it was glued to, and design the carrier (a skill, an agent, a tool) that lands the pattern here. You do **not** build it — that's the pipeline.

This is the workflow that turns inspiration into a feature. It is **design-only**, like the kit's other design skills: it produces the brief and the adaptation design, then hands the build to `/architecture-planning` → `@bagnik` → `@cmok`.

## When to Use

- `/patterns-adapting <url|repo|gist>` — research and adapt a named source.
- `/patterns-adapting "<technique>"` — adapt a known technique with no single canonical source.
- When you want an external idea or tool's *value* in the project without importing its accidental complexity or a hard dependency on it.

## Bootstrap

```bash
.claude/skills/patterns-adapting/new-adaptation.sh <slug>
```

The slug names the pattern (`llm-wiki`, `printing-press`, `debug-mode`). Creates `.tlk/features/YYYY-MM-DD-adapt-<slug>/` with `research-brief.md`, `adaptation.md`, and `handoff-log.md`. The adaptation is a feature like any other — same folder conventions, same handoff log, same archive path.

You originate the feature, so set the L1 hot state once the folder exists:

```bash
talaka/memory/tools/session.sh feature adapt-<slug>
talaka/memory/tools/session.sh agent patterns-adapting
```

## Phase 0 — Resolve the source

Establish what the source actually is, where it lives, and what its **license** permits (attribution, copyleft, none). Record this in `research-brief.md` — the build inherits these constraints. Strip the marketing: write one plain line for what it does.

## Phase 1 — Research brief

Fill `research-brief.md`:

1. **Core insight.** One sentence naming the single idea that makes the pattern work (the canonical example: Karpathy's LLM-wiki — *the tedious part of a knowledge base isn't reading or thinking, it's the bookkeeping*; the model never gets bored of bookkeeping). Everything else is mechanics or incidental. **No core insight, no adaptation** — you'd be copying code you don't understand.
2. **Essential vs incidental.** Separate the load-bearing mechanics from what's glued to the source's original stack, scale, or domain. The incidental parts are exactly what you must *not* port.
3. **Evidence reviewed.** What you actually read or ran (read-only).

## Phase 2 — Adaptation design

Fill `adaptation.md`:

- **Carrier.** Decide the form the pattern takes here — a new skill, a new agent, a tool/script, a convention, or an extension of an existing one. Name it per the project's naming convention.
- **Mapping.** Every essential mechanic → a concrete home in this project (`.tlk/` artifact path, naming, memory layer, handoff edge). A mechanic with no project-side home is not yet designed.
- **Fit with conventions.** Artifact locations, invocation (`/name` or `@name`), handoff target, what it reads/logs in memory.
- **Deliberately NOT ported.** Name what you're leaving behind and why — incidental complexity, an incompatible dependency, scale this project doesn't have.
- **Self-containment.** State any external runtime dependency introduced. The adapted artifact must stand on its own — never leave a hard dependency on an external plugin/tool unless that dependency is the explicit point of the feature.
- **Attribution.** How the source is credited, per its license.

## Phase 3 — Handoff to the pipeline

The build is **not** yours. Append to `handoff-log.md` and hand off to `/architecture-planning` (architecture + tests), citing both artifacts. From there the normal flow applies: architecture-planning → `@bagnik` (test gate) → `@cmok` (build) → `@bagnik` (code QA) → `@zlydni`.

## Guardrails

- **No build.** You produce the brief and the design; `@cmok` builds. No scaffolding beyond illustrative snippets in `adaptation.md`.
- **No verbatim copy.** Re-express the pattern in this project's idiom; don't paste incompatible code or import accidental complexity.
- **No core insight, no design.** If you can't name what makes the pattern work in one sentence, say so and ask the user whether a straight port is really what they want.
- **Stay self-contained.** Don't introduce a runtime dependency on an external plugin/skill/tool unless that is the explicit intent — re-express the idea natively.
- **Respect the license.** Attribute the source; don't adopt code the license forbids.

## Memory

Read `.tlk/MEMORY.md` (L4) first — a prior adaptation may have settled where patterns of this kind live or which conventions they follow; don't relitigate them. When the design lands a durable decision (the carrier form, an excluded dependency, the attribution approach), record it in L1 as you go: `talaka/memory/tools/session.sh decision "Chose X over Y because …"` — these accumulate in the hot state and Zlydni promotes them to L2 when the feature is committed. Capture the source + insight with `talaka/memory/tools/log.sh --type decision "<source> → <core insight>"` so the pattern's provenance is preserved.
