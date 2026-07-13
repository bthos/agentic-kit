# Wiki Schema

This file is the **ontology** for `wiki/` — the conventions knowledge-curating follows on every ingest, query, and lint. Amend it to fit the project (add categories, page types, naming rules); knowledge-curating reads it before every operation and obeys what it finds here.

Pattern: Andrej Karpathy's LLM-wiki — a persistent, interlinked markdown wiki maintained by the LLM, sitting between raw sources and queries, so knowledge compounds instead of being re-derived.

## Layout

```
wiki/
├── SCHEMA.md      ← this file (conventions; project-amendable)
├── index.md       ← content catalog of every page, by category; updated on every ingest
├── log.md         ← append-only operation log
├── sources/       ← raw sources — IMMUTABLE (never edited, never deleted)
└── pages/         ← LLM-owned wiki pages
```

The wiki is committed to git. `sources/` may hold anything textual (md, txt, html-saved-as-text, code excerpts); binary originals should live elsewhere with a pointer page here.

## Page types and naming

All pages are kebab-case markdown in `pages/`. The prefix encodes the type:

| Type | Filename | Purpose |
|------|----------|---------|
| **source** | `src-<slug>.md` | Summary + assessment of one raw source. Exactly one per ingested source. |
| **entity** | `ent-<slug>.md` | A person, system, tool, org, or artifact mentioned across sources. |
| **concept** | `con-<slug>.md` | An idea, technique, or theme that recurs across sources. |
| **synthesis** | `syn-<slug>.md` | A persisted answer — cross-page reasoning worth keeping. |

## Page shape

```markdown
---
type: source | entity | concept | synthesis
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: [sources/<file>, …]        # which raw sources back this page
superseded_by: pages/<file>         # OPTIONAL — set by lint, never delete
---

# Title

One-paragraph summary a reader can stop after.

## <Body sections as needed>

Claims reference their backing: inline `(per [[src-foo]])` or a Sources footer.
Related pages are linked as [[wikilinks]] — link liberally, both directions.
```

Rules:

1. **`sources:` is mandatory** for source pages and strongly expected elsewhere — a claim with no source is an opinion and should say so.
2. **`updated:` is touched on every edit.** Lint uses it to find stale pages.
3. **`superseded_by:` instead of deletion.** The past stays visible (Навь principle), just de-emphasised in the index.
4. **`[[wikilink]]` targets are page filenames without `.md`** (e.g. `[[ent-postgres]]`). A link to a page that doesn't exist yet is a lint item, not an error.

## index.md format

Content-oriented catalog, grouped by category headings the project finds natural (e.g. `## Architecture`, `## People`, `## Papers`). Every page appears at least once:

```markdown
## <Category>
- [[src-foo]] — one-line hook of what's inside
```

Superseded pages move to a final `## Superseded` section rather than disappearing.

## log.md format

Append-only, newest at the bottom, parseable header per entry:

```markdown
## [YYYY-MM-DD] ingest | <source title>
Pages touched: [[src-foo]], [[ent-bar]] (new), [[con-baz]]

## [YYYY-MM-DD] query | <question>
Answered from [[con-baz]]; persisted as [[syn-qux]].

## [YYYY-MM-DD] lint | 4 issues, 3 fixed
Orphan [[ent-old]] linked from index; contradiction in [[con-baz]] raised to user.
```

## Operation contracts

- **Ingest**: land source → write/refresh `src-` page → update every touched entity/concept page (10–15 pages in one pass is normal) → update `index.md` → append `log.md`.
- **Query**: read `index.md` → follow links → answer with citations → persist nontrivial synthesis as a `syn-` page. The wiki targets ≤ ~100k tokens total; at that scale direct reading beats retrieval machinery, so there is deliberately no embedding index.
- **Lint**: contradictions, stale claims, orphans, broken wikilinks, missing concept pages, index drift. Fix mechanical issues; raise judgment calls.

Everything here is modular — keep what's useful, amend what isn't, record amendments in this file so the next session inherits them.
