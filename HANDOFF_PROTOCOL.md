# Agent Handoff Protocol

Structured handoff format for agent-to-agent transitions. **Explicit handoffs reduce context loss and improve task completion.**

*Agents: Zheuzhyk, Vadavik, Lojma, Laznik, Cmok, Bahnik, Zlydni, Pisar.*

## Autonomous Flow

Agents hand off to each other **without user intervention** where possible. Flow stops only when user input is required.

| Transition | Auto? | User stop? |
|------------|-------|------------|
| Vadavik → Lojma | ✅ | — |
| Lojma → Pisar + Cmok mockup | ✅ | — |
| Cmok mockup → User UAT | — | **Yes** — user must approve mockups |
| User UAT → Laznik | — | **Yes** — user confirms to proceed |
| Laznik → Bahnik | ✅ | — |
| Bahnik (pass) → Cmok build | ✅ | — |
| Cmok build → Bahnik + Pisar | ✅ | — |
| Bahnik (pass) → Zlydni | ✅ | — |
| Bahnik (fail) Phase 2 → Laznik | ✅ | — |
| Bahnik (fail) Phase 3 → Cmok | ✅ | — |
| Zlydni → End | — | Optional — user may push |

**Background subagents:** Pisar (`background: true`) runs in parallel. Cmok, Bahnik, Zlydni run foreground for sequential handoff.

## Principles

- **Interrupt when valuable** — Have a valuable thought → interrupt. Have nothing to add → remain silent. Agents may interrupt each other, speak out of turn, or stay silent.
- **Explicit over implicit** — Never assume context carries; pass it explicitly
- **Structured format** — Use the handoff template below
- **Justify routing** — Explain why the next agent is appropriate
- **Zheuzhyk orchestrates** — Zheuzhyk guides handoffs; invoke via Zheuzhyk when uncertain
- **Auto-handoff** — When completing, invoke next agent via the Agent tool unless user stop

## Handoff Template

When handing off to another agent, include:

```markdown
## Handoff: [From Agent] → [To Agent]

**Phase:** [1 | 2 | 3]
**Trigger:** [Task completed | Blocked | User request]
**Feature path:** `.artefacts/features/YYYY-MM-DD-feature-name/` (or `.artefacts/archive/...` if archived)

### Deliverables
- [Artifact 1]: [path or description]
- [Artifact 2]: [path or description]

### Context
- **Decisions:** [Key decisions made]
- **Constraints:** [Limitations, dependencies]
- **Blockers:** [None | List if any]

### Next Agent
**Invoke:** `/vadavik` `/lojma` `/laznik` `/zheuzhyk` or `@cmok` `@bahnik` `@zlydni` `@pisar`
**Why:** [One-line justification for this agent]
**Prompt:** [Suggested prompt for next agent]
**Mode constraint:** [If Phase 1: "Read-only stance, no impl." If Phase 3 build: "Full Agent mode."]
```

**Feature path rule:** All feature artifacts live in `.artefacts/features/YYYY-MM-DD-feature-name/`. Include this path in every handoff so the next agent knows where to read/write. When feature is complete, move folder to `.artefacts/archive/`.

## Agent-Specific Handoff Checklists

**Vadavik → Lojma:** Open questions listed? Deferred decisions documented? Feature path included?
**Lojma → Cmok:** States matrix for each screen? UX path? Key decisions?
**Lojma → Pisar:** UX path? Key flows to document?
**Laznik → Bahnik:** Coverage summary? Known gaps? Arch path? Test paths?
**Cmok → Bahnik:** Feature path? What was built? Changed files? New storage/API?
**Cmok → Pisar:** What was built? Feature path? Spec/UX/tech plan paths?
**Bahnik → Zlydni:** Phase: 3. Feature path. Changed files. Safe to commit.

## Phase Handoff Map

| From | To | Phase | Invocation | Auto? |
|------|-----|------|------------|-------|
| Idea/User | Vadavik | 1 | `vadavik` | — |
| Vadavik | Lojma | 1 | `lojma` | ✅ |
| Lojma | Pisar (parallel) | 1 | `@pisar` | ✅ |
| Lojma | Cmok | 2 | `cmok` skill (mockups) | ✅ |
| Cmok mockup | User UAT | 2 | — | **STOP** |
| User UAT | Laznik | 2 | `laznik` | **STOP** |
| Laznik | Bahnik | 2 | `@bahnik` test gate | ✅ |
| Bahnik (pass) | Cmok | 3 | `@cmok` agent (build) | ✅ |
| Cmok | Pisar (parallel) | 3 | `@pisar` | ✅ |
| Cmok | Bahnik | 3 | `@bahnik` code QA | ✅ |
| Bahnik (pass) | Zlydni | 3 | `@zlydni` | ✅ |
| Bahnik (fail) Phase 2 | Laznik | 2 | `laznik` | ✅ |
| Bahnik (fail) Phase 3 | Cmok | 3 | `@cmok` | ✅ |
| Zlydni | End | 3 | — | Optional push |

**Phase 3 one-shot:** Invoke Zheuzhyk (`/zheuzhyk`) with "build and ship" — Zheuzhyk confirms Phase 2 passed, then starts Cmok; chain runs Cmok → Bahnik → Zlydni automatically. Bahnik fail → Cmok fix → Bahnik. **Loop repeats until Bahnik passes** — no iteration limit.

## Quality Gates

- **Bahnik test gate** (Phase 2) — Block if tests fail. Do not proceed to Phase 3.
- **Bahnik code QA** (Phase 3) — Block if QA fails. Do not proceed to Zlydni.
- **Bahnik security & PII** — Block if security issues or personal data leaks found.
- **Nothing ships without passing Bahnik.** Bahnik does not negotiate.

## Invocation Format (Claude Code)

- **Skills** (conversational, slash commands): `/vadavik`, `/lojma`, `/laznik`, `/zheuzhyk` — type in chat
- **Subagents** (focused execution): `@cmok`, `@bahnik`, `@zlydni`, `@pisar` — @-mention or name in chat
- **Phase 3 one-shot**: `/zheuzhyk` with "build and ship" or "run Phase 3"

## Best Practices

1. **Include file paths** — Receiving agent needs to know what to read
2. **Include feature path** — Always pass `.artefacts/features/YYYY-MM-DD-feature-name/` (or archive path) in handoffs
3. **Summarize decisions** — Don't make the next agent re-derive
4. **Flag blockers early** — If blocked, hand back to Zheuzhyk or the appropriate agent
5. **Parallel handoffs** — Pisar can run alongside Lojma or Cmok; pass same context to both
6. **Close feature after commit** — After Zlydni commit, move feature folder to `.artefacts/archive/`. Feature is closed after commit.
7. **Version bumping** — Cmok: bump patch before each build. Zlydni: bump minor before commit. Update both `package.json` and `manifest.json`.
8. **Pisar handoff template:** Feature path, Spec path, UX path, Tech plan path, What was built, Document: [scope]
