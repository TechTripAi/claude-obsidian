# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# claude-obsidian — Claude + Obsidian Wiki Vault

This folder is both a Claude Code plugin and an Obsidian vault.

Two modes of work happen here, and they have different rules:
- **Using the vault** — ingesting sources, querying, linting. Governed by the vault conventions below.
- **Developing the plugin** — editing `skills/`, `scripts/`, `bin/`, `hooks/`, `agents/`. Governed by the commands and architecture sections below. This repo *is* the plugin's source; the vault content is the live dogfood of it.

**Plugin name:** `claude-obsidian` (v1.7+ "Compound Vault" — see [docs/compound-vault-guide.md](docs/compound-vault-guide.md); v1.8+ adds methodology modes — see [docs/methodology-modes-guide.md](docs/methodology-modes-guide.md))
**Skills:** 17 under `skills/<name>/SKILL.md` — see the table below.
**Vault path:** This directory (open in Obsidian directly)

## What This Vault Is For

This vault demonstrates the LLM Wiki pattern — a persistent, compounding knowledge base for Claude + Obsidian. Drop any source, ask any question, and the wiki grows richer with every session.

## Vault Structure

```
.raw/           source documents — immutable, Claude reads but never modifies
wiki/           Claude-generated knowledge base
_templates/     Obsidian Templater templates
_attachments/   images and PDFs referenced by wiki pages
```

## How to Use

Drop a source file into `.raw/`, then tell Claude: "ingest [filename]".

Ask any question. Claude reads the index first, then drills into relevant pages.

Run `/wiki` to scaffold a new vault or check setup status.

Run "lint the wiki" every 10-15 ingests to catch orphans and gaps.

## Development Commands

```bash
make test              # all 9 suites — CI runs this on every PR
make help              # list every target with a one-line description
make test-lock         # run one suite (targets: test-address, test-tiling, test-boundary,
                       # test-bm25, test-retrieve, test-lock, test-concurrent, test-mode, test-contextual)
bash tests/test_wiki_lock.sh          # run a shell suite directly
python3 tests/test_retrieve.py        # run a python suite directly
make clean-test-state  # remove runtime lockfiles + tiling/embed/transport caches
```

All suites are hermetic — no network, no ollama, no API key required. A suite that needs one of those must synthesize or skip, not reach out. `make clean-test-state` is the escape hatch when a run leaves `.vault-meta/` state behind and tests start failing for no apparent reason.

Beyond `make test`, CI also validates SKILL.md frontmatter and `plugin.json` JSON validity. Contribution workflow and commit conventions: [CONTRIBUTING.md](CONTRIBUTING.md).

## Repo Architecture

The plugin's moving parts, and what reads what:

| Path | Role |
|------|------|
| `skills/<name>/SKILL.md` | The 17 skills. Markdown-defined behavior — a skill *is* its SKILL.md plus its `references/`. Frontmatter follows the cross-platform Agent Skills spec (kepano convention: `name` + `description` only on newer skills). |
| `scripts/` | The executable substrate the skills shell out to (`wiki-lock.sh`, `wiki-mode.py`, `retrieve.py`, `bm25-index.py`, `detect-transport.sh`, …). Skills stay declarative; logic lives here where it can be tested. |
| `tests/` | One hermetic suite per script. New script ⇒ new suite. |
| `bin/setup-*.sh` | User-facing, idempotent, opt-in installers. Anything that costs money or egresses data is default-off and prompts for consent here. |
| `hooks/hooks.json` | Session lifecycle (see below). |
| `agents/verifier.md` | Read-only pre-commit auditor. |
| `commands/` | Thin `/command` entry points that route into skills. |
| `.vault-meta/` | All runtime state (mode, transport, caches, locks). Gitignored by default. |

The layering that matters: **`commands/` → `skills/` → `scripts/` → `.vault-meta/`**. When adding behavior, push logic down to `scripts/` with a test, and keep the SKILL.md as orchestration prose. Feature detection (does this vault have retrieval? which mode?) is always a `.vault-meta/` read, never a hardcoded assumption — that's what lets v1.7/v1.8 features be opt-in without the consumer skills special-casing.

## Vault Conventions

These are invariants, not preferences — the skills assume them:

1. **Never modify `.raw/`.** Sources are immutable. Claude reads, never writes.
2. **`wiki/log.md` is append-only.** Never edit or rewrite past entries.
3. **`wiki/hot.md` is a cache, not a journal.** It gets overwritten wholesale at session end, capped ~500 words.
4. **Internal references are wikilinks** (`[[Note Name]]`), never relative paths.
5. **Frontmatter is flat YAML.** See `skills/wiki/references/frontmatter.md`.
6. **`.raw/.manifest.json` tracks ingested sources** for delta detection — a source-touching change must keep it reconciled.

## Hook Behavior

`hooks/hooks.json` wires four lifecycle points, and one of them will surprise you:

- **PostToolUse (Write|Edit) auto-commits** `wiki/`, `.raw/`, and `.vault-meta/` to git. Edits to vault content land as commits without you asking. It defers while `wiki-lock` holds any lock, and honors a `.vault-meta/auto-commit.disabled` killswitch.
- **SessionStart** cats `wiki/hot.md` into context and clears locks stale >1h.
- **PostCompact** re-reads `wiki/hot.md` (hook-injected context doesn't survive compaction).
- **Stop** prompts for a hot-cache refresh if `wiki/` changed.

## Doc Fanout

The skill list and vault conventions are mirrored across `AGENTS.md`, `GEMINI.md`, `.cursor/rules/claude-obsidian.mdc`, `.github/copilot-instructions.md`, and `README.md` for cross-agent support. Adding or renaming a skill means updating these together — they drift silently otherwise.

## Cross-Project Access

To reference this wiki from another Claude Code project, add to that project's CLAUDE.md:

```markdown
## Wiki Knowledge Base
Path: /path/to/this/vault

When you need context not already in this project:
1. Read wiki/hot.md first (recent context, ~500 words)
2. If not enough, read wiki/index.md
3. If you need domain specifics, read wiki/<domain>/_index.md
4. Only then read individual wiki pages

Do NOT read the wiki for general coding questions or things already in this project.
```

## Plugin Skills

| Skill | Trigger |
|-------|---------|
| `/wiki` | Setup, scaffold, route to sub-skills |
| `ingest [source]` | Single or batch source ingestion |
| `query: [question]` | Answer from wiki content |
| `lint the wiki` | Health check |
| `/save` | File the current conversation as a structured wiki note |
| `/autoresearch [topic]` | Autonomous research loop: search, fetch, synthesize, file |
| `/canvas` | Visual layer: add images, PDFs, notes to Obsidian canvas |
| `/defuddle` | Strip ads/nav/boilerplate from a URL before ingest |
| `/wiki-fold` | Log rollup into fold pages (DragonScale Mechanism 1, opt-in) |
| `/wiki-delete` | Safe page deletion — reconciles backlinks, index, counter, manifest |
| `/wiki-archive` | Cold storage: retire pages to `wiki/archives/<year>/`, raw sources to `.archive/` |
| `/obsidian-markdown` | Obsidian Flavored Markdown reference — read before writing any wiki page |
| `/obsidian-bases` | Obsidian Bases (`.base` files): dynamic tables, filters, formulas |
| `/wiki-cli` (v1.7) | Obsidian CLI transport wrapper; default mutation path on desktop |
| `/wiki-retrieve` (v1.7) | Hybrid contextual + BM25 + cosine-rerank retrieval (opt-in via `bash bin/setup-retrieve.sh`) |
| `/wiki-mode` (v1.8) | Methodology modes (LYT / PARA / Zettelkasten / Generic). Set via `bash bin/setup-mode.sh`; consumed by wiki-ingest / save / autoresearch for routing new pages |
| `/think` (v1.9) | The 10-principle thinking loop (OBSERVE-OBSERVE-LISTEN-THINK-CONNECT-CONNECT-FEEL-ACCEPT-CREATE-GROW) as an invocable workflow. Apply to architectural decisions, audits, post-mortems, ambiguous user requests. Every other skill has a "How to think" appendix mapping this framework to its specific work |

## Transport (v1.7+)

`scripts/detect-transport.sh` writes `.vault-meta/transport.json` on first run and refreshes weekly. Skills consult it before mutating the vault. Fallback chain: Obsidian CLI → mcp-obsidian → mcpvault → filesystem (always-available floor). Decision tree: [wiki/references/transport-fallback.md](wiki/references/transport-fallback.md).

## Concurrency (v1.7+)

`scripts/wiki-lock.sh` provides per-file advisory locks for safe multi-writer ingest. Every wiki page write should be guarded by `wiki-lock acquire`/`release`. Stale-after default is 60s; cross-process release allowed by design. The PostToolUse hook defers `git add` while locks are held. Closes the latent multi-writer corruption hole from v1.6.

## Methodology Modes (v1.8+)

Pick an organizational style for the vault via `bash bin/setup-mode.sh`. Four modes available: **generic** (v1.7 default — no opinion), **LYT** (Linking Your Thinking — MOCs + atomic notes), **PARA** (Projects/Areas/Resources/Archives), **Zettelkasten** (timestamped IDs, flat, dense linking). The mode is written to `.vault-meta/mode.json` (gitignored by default; `git add -f` to commit). `wiki-ingest`, `save`, and `autoresearch` consult `python3 scripts/wiki-mode.py route <type> "<name>"` before filing new pages — no special-casing needed in the consumer skills. Full guide: [docs/methodology-modes-guide.md](docs/methodology-modes-guide.md). Closes priority gap 5 from the May 2026 compass artifact.

## Pre-commit verifier (v1.7.1+)

After staging changes for a non-trivial workstream but BEFORE running `git commit`, dispatch the `verifier` agent (`agents/verifier.md`). It reads `git diff --cached`, applies the /best-practices six-cut + agent kernel, and returns findings in four tiers (BLOCKER / HIGH / MEDIUM / LOW) with file:line citations. The agent has read-only tools (Read, Grep, Glob, Bash) — it can inspect but never modify, so its output is purely advisory. This closes the loop the v1.7 audit revealed: code went worker → commit with no separate verifier pass, which is how BLOCKER B1 (data-egress consent gap) slipped through. See `docs/audits/v1.7.0-audit-2026-05-17.md` §10 for the retrospective.

## MCP (Optional)

If you configured the MCP server, Claude can read and write vault notes directly.
See `skills/wiki/references/mcp-setup.md` for setup instructions.

## Release Blog Post

After cutting a new release (git tag + `gh release create`), run:

```
/release-blog
```

This generates a blog post on https://agricidaniel.com/blog/, handles cover image generation, SEO metadata, FAQ schema, internal linking, sitemap/llms.txt updates, Vercel deployment, and Google indexing.
