# Development pipeline

@PROJECT.md

---

## Pipeline Overview

A self-organizing team of agents. Each agent knows who to hand off to next based on the context it receives. Nothing ships without passing Bahnik.

```
Idea → Vadavik (spec) → Lojma (UX) + Veles (docs, parallel)
     → Cmok /skill/ (mockups) → User UAT
     → Laznik (arch + tests) → Bahnik (test gate)
     → Cmok /agent/ (build) + Veles (docs, parallel) → Bahnik (code QA)
     → Zlydni (commit + archive)
```

### Agents

| Agent   | Role                        | Model  |
|---------|-----------------------------|--------|
| Bahnik  | Test gate & code QA         | Opus   |
| Cmok    | Build                       | Sonnet |
| Veles  | Documentation               | Sonnet |
| Zlydni  | Commits & version control   | Haiku  |

### Skills

| Skill     | Role                          |
|-----------|-------------------------------|
| Vadavik   | Spec & requirements           |
| Lojma     | UX design                     |
| Cmok      | UX mockups                    |
| Laznik    | Architecture & tests          |

### Invocation

**Skills** (slash commands in chat): `/vadavik`, `/lojma`, `/laznik`, `/cmok` (mockups only)
**Agents** (@-mention or Agent tool): `@bahnik`, `@cmok` (build), `@veles`, `@zlydni`

---

## Handoff Protocol

Structured handoff format for agent-to-agent transitions. Explicit handoffs reduce context loss.

*Agents: Vadavik, Lojma, Laznik, Cmok, Bahnik, Zlydni, Veles.*

### Autonomous Flow

Agents hand off to each other without user intervention where possible. Flow stops only when user input is required.

| Transition | Auto? | User stop? |
|------------|-------|------------|
| Vadavik → Lojma | yes | — |
| Lojma → Veles + Cmok mockup | yes | — |
| Cmok mockup → User UAT | — | **Yes** — user must approve mockups |
| User UAT → Laznik | — | **Yes** — user confirms to proceed |
| Laznik → Bahnik | yes | — |
| Bahnik (test gate pass) → Cmok build | yes | — |
| Cmok build → Bahnik + Veles | yes | — |
| Bahnik (code QA pass) → Zlydni | yes | — |
| Bahnik (test gate fail) → Laznik | yes | — |
| Bahnik (code QA fail) → Cmok | yes | — |
| Zlydni → End | — | Optional — user may push |

**Background subagents:** Veles (`background: true`) runs in parallel. Cmok, Bahnik, Zlydni run foreground for sequential handoff.

### Principles

- **Interrupt when valuable** — Have a valuable thought → interrupt. Have nothing to add → remain silent.
- **Explicit over implicit** — Never assume context carries; pass it explicitly
- **Structured format** — Use the handoff template below
- **Justify routing** — Explain why the next agent is appropriate
- **Auto-handoff** — When completing, invoke next agent via the Agent tool unless user stop

### Handoff Template

When handing off to another agent, include:

```markdown
## Handoff: [From Agent] → [To Agent]

**Context:** [spec | design | mockups | test gate | build | code QA | commit]
**Trigger:** [Task completed | Blocked | User request]
**Feature path:** `.artefacts/features/YYYY-MM-DD-feature-name/`

### Deliverables
- [Artifact 1]: [path or description]
- [Artifact 2]: [path or description]

### Context
- **Decisions:** [Key decisions made]
- **Constraints:** [Limitations, dependencies]
- **Blockers:** [None | List if any]

### Next Agent
**Invoke:** `/vadavik` `/lojma` `/laznik` or `@cmok` `@bahnik` `@zlydni` `@veles`
**Why:** [One-line justification for this agent]
**Prompt:** [Suggested prompt for next agent]
```

**Feature path rule:** All feature artifacts live in `.artefacts/features/YYYY-MM-DD-feature-name/`. Include this path in every handoff so the next agent knows where to read/write. When feature is complete, Zlydni moves the folder to `.artefacts/archive/`.

### Agent-Specific Handoff Checklists

**Vadavik → Lojma:** Open questions listed? Deferred decisions documented? Feature path included?
**Lojma → Cmok:** States matrix for each screen? UX path? Key decisions?
**Lojma → Veles:** UX path? Key flows to document?
**Laznik → Bahnik:** Coverage summary? Known gaps? Arch path? Test paths?
**Cmok → Bahnik:** Feature path? What was built? Changed files? New storage/API?
**Cmok → Veles:** What was built? Feature path? Spec/UX/tech plan paths?
**Bahnik → Zlydni:** Bahnik passed. Feature path. Changed files. Safe to commit.

### Handoff Map

| From | To | Invocation | Auto? |
|------|-----|------------|-------|
| Idea/User | Vadavik | `/vadavik` | — |
| Vadavik | Lojma | `/lojma` | yes |
| Lojma | Veles (parallel) | `@veles` | yes |
| Lojma | Cmok | `/cmok` (mockups) | yes |
| Cmok mockup | User UAT | — | **STOP** |
| User UAT | Laznik | `/laznik` | **STOP** |
| Laznik | Bahnik | `@bahnik` (test gate) | yes |
| Bahnik (test gate pass) | Cmok | `@cmok` (build) | yes |
| Cmok | Veles (parallel) | `@veles` | yes |
| Cmok | Bahnik | `@bahnik` (code QA) | yes |
| Bahnik (code QA pass) | Zlydni | `@zlydni` | yes |
| Bahnik (test gate fail) | Laznik | `/laznik` | yes |
| Bahnik (code QA fail) | Cmok | `@cmok` | yes |
| Zlydni | End | — | Optional push |

**Bahnik context inference:** Bahnik determines its role from who invoked it. From Laznik = test gate (fail → Laznik, pass → Cmok build). From Cmok = code QA (fail → Cmok, pass → Zlydni). Fix loops repeat until Bahnik passes — no iteration limit.

### Quality Gates

- **Bahnik test gate** — Block if tests fail. Do not proceed to build.
- **Bahnik code QA** — Block if QA fails. Do not proceed to Zlydni.
- **Bahnik security & PII** — Block if security issues or personal data leaks found.
- **Nothing ships without passing Bahnik.** Bahnik does not negotiate.

### Invocation Format (Claude Code)

- **Skills** (conversational, slash commands): `/vadavik`, `/lojma`, `/laznik` — type in chat
- **Subagents** (focused execution): `@cmok`, `@bahnik`, `@zlydni`, `@veles` — @-mention or name in chat

### Handoff Log

Each feature folder contains a `handoff-log.md` created by `skills/vadavik/new-feature.sh`. Every agent appends one entry before handing off:

```markdown
## HH:MM [From] → [To] [context]
Key decisions: ...
Artifacts: ...
```

This gives any agent a full chain of custody when context is lost, especially across Bahnik-Cmok fix loop iterations. `tools/feature-status.sh` checks whether the log exists.

### Best Practices

1. **Include file paths** — Receiving agent needs to know what to read
2. **Include feature path** — Always pass `.artefacts/features/YYYY-MM-DD-feature-name/` in handoffs
3. **Summarize decisions** — Don't make the next agent re-derive
4. **Flag blockers early** — Hand back to the appropriate agent
5. **Parallel handoffs** — Veles can run alongside Lojma or Cmok; pass same context to both
6. **Close feature after commit** — After Zlydni commit, move feature folder to `.artefacts/archive/`
7. **Version bumping** — Cmok: bump patch before each build. Zlydni: bump minor before commit. Update all version files listed in Project-Specific Configuration.
8. **Veles handoff template:** Feature path, Spec path, UX path, Tech plan path, What was built, Document: [scope]
