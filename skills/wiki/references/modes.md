# Wiki Modes

Six modes cover the most common use cases. Pick the one that fits, combine them, or define a custom one.

A wiki mode is **not an Obsidian feature**. It is a convention the `/wiki` skill writes into the vault: a folder set, a frontmatter schema for the main note type, a few hub pages, and the filing rules in the vault's `CLAUDE.md`. Nothing enforces it except Claude reading those rules at the start of every ingest. That makes the mode the one part of the vault the user is meant to shape.

Two different axes share the word "mode". The **wiki modes A-F** on this page are scaffold templates: what folders exist and what the main note type tracks. The **methodology mode** from `/wiki-mode` (generic, LYT, PARA, Zettelkasten; stored in `.vault-meta/mode.json`) is a filing-style router that `wiki-ingest`, `save`, and `autoresearch` call before writing a page. A vault has one of each. This page is about the first axis.

## At a glance

Show this table **before** asking what the vault is for. Pick by what the raw sources will be and what question the user will ask most.

| Mode | For | Atomic unit | Extra folders | Frontmatter tracks | "Done" looks like |
|------|-----|-------------|---------------|--------------------|-------------------|
| **A** Website / Sitemap | a site's URLs: crawls, analytics, GSC exports | one page per URL | pages, structure, audits, keywords | HTTP status, meta, indexed, canonical, link counts | no gaps, no broken redirects |
| **B** GitHub / Repository | a codebase: README, git log, code, issues | one page per module | modules, components, decisions, dependencies, flows | path, language, depends_on, used_by | every module documented with its flows |
| **C** Business / Project | meetings, Slack, docs, competitor intel | one page per decision | stakeholders, decisions, deliverables, intel, comms | status, priority, owner, due date | decisions logged, deliverables shipped |
| **D** Personal / Second Brain | journals, articles, podcasts, voice memos | one page per goal | goals, learning, people, areas, resources | area, priority, target date, progress % | goals progressing |
| **E** Research | papers, PDFs, web clips, data | one page per paper | papers, thesis, gaps | year, venue, key claim, methodology, supports, contradicts | a thesis page that reflects every paper |
| **F** Book / Course | chapter notes, highlights, exercises | one page per concept or chapter | characters, themes, timeline, synthesis | status stub→mature, source chapters, first appearance | a synthesis page of the reader's own takeaways |

Differences in plain terms:

- **Time orientation.** C and D look forward (due dates, progress). E and F accumulate. A and B are snapshots refreshed on each crawl or commit.
- **What the frontmatter is for.** A and B track technical state. C and D track ownership and progress. E tracks evidence, with `supports` and `contradicts`. F tracks where in the material something first appeared.

## Folders every mode keeps

In the generic methodology mode (the default when `.vault-meta/mode.json` is absent), `wiki-ingest`, `autoresearch`, and `save` file into `sources/`, `concepts/`, and `entities/`, and `wiki-query` offers to file answers into `questions/`. Under LYT, PARA, or Zettelkasten the `/wiki-mode` router overrides those paths. If techtrip-secondbrain is installed, its `new-idea` skill also files into `projects/`. **Every mode's scaffold must keep `sources/`, `concepts/`, `entities/`, and `questions/`** with a `_index.md` each, beside the mode's own folders, as the floor for generic and unrouted writes; add `projects/` when techtrip-secondbrain is installed. The mode-specific folder lists below are additions, not replacements.

The "Extra folders" column above omits `concepts/` and `entities/` for every mode because every mode keeps them.

---

## Mode A: Website / Sitemap

Use when: "build a sitemap wiki for my website", "map content gaps", "SEO audit wiki"

```
vault/
├── .raw/              # crawl exports, analytics, scraped pages, GSC data
├── wiki/
│   ├── pages/         # one note per URL: status, meta, content summary
│   ├── structure/     # site architecture, nav hierarchy, internal link map
│   ├── audits/        # content gaps, redirect needs, thin content flags
│   ├── keywords/      # keyword clusters, target page assignments
│   └── entities/      # brand, authors, topic hubs
├── _meta/
│   ├── index.md
│   └── log.md
└── CLAUDE.md
```

Frontmatter for `wiki/pages/` notes:
```yaml
---
type: page
url: "https://example.com/page-slug"
status: live          # live | redirect | 404 | stub | no-index
title: ""
h1: ""
meta_description: ""
word_count: 0
has_schema: false
indexed: true
canonical: ""
internal_links_in: 0
internal_links_out: 0
last_crawled: YYYY-MM-DD
tags: [page]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Key wiki pages to create: `[[Site Overview]]`, `[[Navigation Structure]]`, `[[Content Gaps]]`, `[[Redirect Map]]`, `[[Keyword Clusters]]`

---

## Mode B: GitHub / Repository

Use when: "map my codebase", "architecture wiki for my repo", "understand this project"

```
vault/
├── .raw/              # README, git log exports, code dumps, issue exports
├── wiki/
│   ├── modules/       # one note per major module / package / service
│   ├── components/    # reusable UI or functional components
│   ├── decisions/     # Architecture Decision Records (ADRs)
│   ├── dependencies/  # external deps, versions, risk assessment
│   └── flows/         # data flows, request paths, auth flows
├── _meta/
│   ├── index.md
│   └── log.md
└── CLAUDE.md
```

Frontmatter for `wiki/modules/` notes:
```yaml
---
type: module           # module | component | decision | dependency | flow
path: "src/auth/"
status: active         # active | deprecated | experimental | planned
language: typescript
purpose: ""
maintainer: ""
last_updated: YYYY-MM-DD
linked_issues: []
depends_on: []
used_by: []
tags: [module]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Key wiki pages to create: `[[Architecture Overview]]`, `[[Data Flow]]`, `[[Tech Stack]]`, `[[Dependency Graph]]`, `[[Key Decisions]]`

---

## Mode C: Business / Project

Use when: "project wiki", "competitive intelligence", "team knowledge base", "meeting notes"

```
vault/
├── .raw/              # meeting transcripts, Slack exports, docs, emails
├── wiki/
│   ├── stakeholders/  # people, companies, decision-makers
│   ├── decisions/     # key decisions with rationale and date
│   ├── deliverables/  # milestones, outputs, status tracking
│   ├── intel/         # competitor analysis, market research
│   └── comms/         # synthesized meeting notes, key threads
├── _meta/
│   ├── index.md
│   └── log.md
└── CLAUDE.md
```

Frontmatter for `wiki/decisions/` notes:
```yaml
---
type: decision         # stakeholder | decision | deliverable | intel | meeting | competitor
status: active         # active | pending | done | blocked | superseded
priority: 3            # 1 (highest) to 5 (lowest)
date: YYYY-MM-DD
owner: ""
due_date: ""
context: ""
tags: [decision]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Key wiki pages to create: `[[Project Overview]]`, `[[Stakeholder Map]]`, `[[Decision Log]]`, `[[Competitor Landscape]]`

---

## Mode D: Personal / Second Brain

Use when: "personal second brain", "track my goals", "journal synthesis", "life wiki"

```
vault/
├── .raw/              # journal entries, articles, podcast notes, voice transcripts
├── wiki/
│   ├── goals/         # personal and professional goals with progress tracking
│   ├── learning/      # concepts being mastered, skill development
│   ├── people/        # relationships, shared context, follow-ups
│   ├── areas/         # life areas: health, finances, career, creative
│   └── resources/     # books, courses, tools worth referencing
├── _meta/
│   ├── index.md
│   ├── log.md
│   └── hot-cache.md   # ~500-word summary of most active context
└── CLAUDE.md
```

Frontmatter for `wiki/goals/` notes:
```yaml
---
type: goal             # goal | concept | person | area | resource | reflection
status: active         # active | paused | completed | abandoned
area: career           # health | career | finance | creative | relationships | growth
priority: 1
target_date: YYYY-MM-DD
progress: 0            # 0-100 percent
tags: [goal]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Hot cache note: `_meta/hot-cache.md` is a ~500-word file Claude updates at the end of each session. It captures current focus areas, recent wins, and open threads. This prevents Claude from having to crawl the whole wiki to answer "where were we?".

Key wiki pages to create: `[[North Star]]`, `[[Weekly Review Template]]`, `[[Annual Goals]]`

---

## Mode E: Research

Use when: "research wiki on [topic]", "track papers I'm reading", "build a thesis"

```
vault/
├── .raw/              # PDFs, web clips, data files, raw notes
├── wiki/
│   ├── papers/        # paper summaries with key claims and methodology
│   ├── concepts/      # extracted concepts, models, frameworks
│   ├── entities/      # people, organizations, methods, datasets
│   ├── thesis/        # evolving synthesis: the "state of the field" pages
│   └── gaps/          # open questions, contradictions, research needed
├── _meta/
│   ├── index.md
│   └── log.md
└── CLAUDE.md
```

Frontmatter for `wiki/papers/` notes:
```yaml
---
type: paper            # paper | concept | entity | thesis | gap
status: summarized     # raw | summarized | synthesized | superseded
year: 2024
authors: []
venue: ""
key_claim: ""
methodology: ""
contradicts: []
supports: []
tags: [paper]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Key wiki pages to create: `[[Research Overview]]`, `[[Key Claims Map]]`, `[[Open Questions]]`, `[[Methodology Comparison]]`

---

## Mode F: Book / Course

Use when: "companion wiki for a book", "course notes wiki", "as I read [title]"

```
vault/
├── .raw/              # chapter notes, highlights, exercises
├── wiki/
│   ├── characters/    # characters, personas, agents, experts (adapt to content)
│   ├── themes/        # major themes with supporting evidence
│   ├── concepts/      # domain-specific terms and frameworks
│   ├── timeline/      # plot structure, curriculum sequence, chapter map
│   └── synthesis/     # your own takeaways, questions, applications
├── _meta/
│   ├── index.md
│   └── log.md
└── CLAUDE.md
```

Frontmatter for `wiki/concepts/` notes:
```yaml
---
type: concept          # concept | character | theme | chapter | synthesis
status: developing     # stub | developing | mature
source_chapters: []
first_appearance: ""
tags: [concept]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Key wiki pages to create: `[[Book Overview]]`, `[[Theme Map]]`, `[[Character / Expert Index]]`, `[[My Takeaways]]`

---

## Combining Modes

You can combine modes. Examples:

- "GitHub repo + research on the AI approach used" -> Mode B folders + Mode E papers/ folder
- "My SaaS business + second brain" -> Mode C intel/ + Mode D goals/
- "YouTube channel" -> Mode F (content as "book") + Mode E (research on topics covered)

When combining, keep folder names distinct. Don't merge `decisions/` from Mode B and Mode C into one folder.

---

## Custom Modes

When no mode fits, or a mode fits but is missing the output side, define a custom one. A custom mode is nothing more than:

1. A short name, recorded in the vault `CLAUDE.md` `Mode:` line (e.g. `Mode: custom "AI Research and Writing" (Mode E base plus writing/ and projects/)`).
2. The folder set: the folders every mode keeps (see above), plus the folders borrowed from one or more modes, plus any new ones.
3. **Filing rules** in the vault `CLAUDE.md`: one numbered rule per folder boundary, stating what goes where and what the threshold is. These rules are what make the mode real; without them ingest and autoresearch fall back to the generic layout.
4. A Templater template per new note type.

Worked example — a vault for researching AI, writing technical articles about it, and writing AI code:

| Folder | Holds | Rule |
|--------|-------|------|
| sources | every ingested raw file (provenance) | default |
| papers | academic papers only, with Mode E's claim / methodology / supports / contradicts | an arXiv, conference, or lab paper goes here, not to sources |
| concepts, entities | techniques and patterns; models, labs, tools, people | default |
| thesis | state-of-the-field synthesis per topic | create once three or more sources cover a topic; rewrite, do not append |
| gaps | open questions and unresolved contradictions | every unresolved `[!contradiction]` becomes a gap; gaps can serve as the `/autoresearch` queue |
| writing | article outlines and drafts | drafts cite thesis and concept pages, never raw sources |
| projects (techtrip-secondbrain only) | `/new-idea` origination projects | graduate article ideas into writing/, code ideas into concepts/ |
| questions | default | default |

Mode B was considered and rejected for the code side: it maps one codebase, which is not the same as learning to write code. If one repo later becomes central, `modules/` and `flows/` can be added then.
