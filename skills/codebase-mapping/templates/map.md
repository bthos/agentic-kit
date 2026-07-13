# {{MAP_ID}} — Codebase Map

_Filled by /codebase-mapping. Read by architecture-planning, requirements-eliciting, and any agent onboarding to this code. A map is **edges, not just nodes** — name how the parts call each other, not only what exists._

## Scope

- **Mapped:** [whole repo | subdir/module — name it]
- **As of:** commit `[short-sha]` ({{DATE}})
- **Excluded:** [.git, node_modules, build output, vendored deps, .tlk, …]

## One-paragraph orientation

> [What is this codebase, in plain language? What does it do, for whom, and what is the single most important thing a newcomer must understand before touching it?]

## Structure

_Top-level tree with a one-line purpose per significant directory. Collapse noise; expand where the work happens._

```
.
├── [dir]/        ← [purpose]
├── [dir]/        ← [purpose]
└── [file]        ← [purpose]
```

## Entry points

_Where execution actually begins. Every binary, server, CLI, job, or build step a newcomer would run._

| Entry point | File:line | Kind | Starts / does |
|-------------|-----------|------|---------------|
| | `path:line` | [main / CLI / server / build / test] | |

## Components & boundaries

_The 3–8 units the system is really made of. One row each; keep it conceptual, not file-by-file._

| Component | Lives in | Responsibility | Depends on |
|-----------|----------|----------------|------------|
| | `path/` | | |

## Invocation edges

_How control/data flows between components. This is the part a file tree cannot show._

- `[A]` → `[B]`: [what triggers it, what is passed] — `path/to/callsite.ext:line`
- …

## Conventions & schemas

_The implicit rules a newcomer would otherwise learn by breaking them: config file shapes, frontmatter fields, naming patterns, error/exit-code conventions, where state lives._

- **Config:** [files + the schema/keys that matter]
- **Naming:** [pattern, e.g. gerund-noun skill dirs]
- **State / data:** [where persistent state lives]
- **Other:** […]

## Where to make changes

_Pointers for the next role: if you want to do X, start in Y._

| To change… | Start at | Watch out for |
|------------|----------|---------------|
| | `path/` | |

## Sources consulted

- [files read, docs/READMEs, git history (`git log` ranges), prior maps/wiki pages]
