# {{ADAPT_ID}} — Adaptation Design

_Filled by /patterns-adapting (Phase 2). Read by architecture-planning (builds it) and Bagnik (gates it). Maps the source's core insight onto **this** project's conventions — not a copy of the original._

## Carrier

- **Form:** [new skill | new agent | new tool/script | doc/convention | extension of an existing one]
- **Name:** [if a skill/agent — follow the project's naming convention; if extending, name the target]
- **One-line purpose:** [what it does here]

## Mapping

_Every adopted mechanic → where it lives in this project. This is the adaptation; a row with no project-side home is not yet designed._

| From the source | Becomes here | Location / convention |
|-----------------|--------------|-----------------------|
| [essential mechanic] | [concrete artifact] | [`.tlk/…`, naming, memory layer, handoff edge] |

## Fit with conventions

- **Artifacts:** [where outputs land — `.tlk/...` / `wiki/` / committed?]
- **Invocation & handoff:** [how it's invoked (`/name` or `@name`) and who it hands off to]
- **Memory:** [what it reads (L4) / logs, if anything]

## Deliberately NOT ported

_What from the source is being left behind, and why — incidental complexity, an incompatible dependency, scale the project doesn't have._

- [element] — [why excluded]

## Self-containment

- **External runtime dependency introduced?** [none | name it + justification]
- _The adapted artifact must stand on its own — never leave a hard dependency on an external plugin/tool unless that dependency is the explicit point of the feature._

## Attribution

- [how the source is credited — link in the artifact/docs, per its license]

## Open questions

- [ ] [anything the build needs the user to decide]
