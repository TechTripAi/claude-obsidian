---
name: wiki-archive
description: "Move cold material out of the live wiki without losing it. Two warm tiers inside the vault: retired pages go to wiki/archives/<year>/ (status: archived, index + address_map reconciled), cold raw sources go to .archive/ (raw_file: pointer and manifest key updated so provenance survives). Also prints the manual steps for the cold tier — a passive second vault. Triggers on: archive this page, archive this source, move to archive, cold storage, retire but keep, park this page, clean out .raw."
---

# wiki-archive: Cold Storage Without Rot

Deletion (wiki-delete) is for material that should not exist; **archiving is for material that earned its keep but no longer belongs in the live graph** — finished projects, superseded sources, cold inbox files. A bare `mv` rots the same records a bare `rm` does: index paths, the manifest's path-keyed entries, `raw_file:` provenance pointers. This skill moves things *with* their bookkeeping.

Like wiki-delete: **never chain into this skill**; archive only what the user explicitly named.

---

## The three tiers (know which one you're in)

| Tier | What moves | Where | Reach afterward |
|---|---|---|---|
| **Warm — pages** | A retired wiki page | `wiki/archives/<year>/` | Still in the vault: wikilinks keep resolving (filename-based), query/lint still see it, `status: archived` marks it retired |
| **Warm — raw sources** | A cold `.raw/` file already ingested | `.archive/` (vault root) | Out of the inbox; provenance pointer updated so the audit trail survives |
| **Cold — passive vault** | Truly dead material | A separate archive vault (own repo) | Outside this vault entirely: no MCP, no query, no lint. Manual move; this skill only prints the steps |

---

## Modes

| Mode | Writes? | Invocation |
|---|---|---|
| **plan (default)** | **No Write/Edit calls, no mv.** Emit the move plan via Bash stdout only. | `archive [[Page]]` / `archive .raw/articles/foo.md` |
| **commit** | Uses Edit/Bash mv. Each Edit fires the PostToolUse hook which auto-commits. Accept this. | Only after the user confirms the plan |

Same stdout-only rationale as wiki-fold/wiki-delete: the plan must leave zero residue.

---

## Concurrency (v1.7+)

Commit mode holds locks on every file it edits (`scripts/wiki-lock.sh acquire`/`release`), per `skills/wiki-ingest/SKILL.md` §Concurrency: the moving page (or source page whose `raw_file:` is being updated), `wiki/index.md`, `wiki/log.md`.

---

## Tier 1 — Archive a wiki page

**What does NOT break:** wikilinks. Obsidian links by unique filename, not path, so `[[Page Name]]` keeps resolving after the move. Do not rewrite backlinks for a warm page archive.

**What DOES need reconciling** (path-keyed records):

1. **Plan (stdout)**: show the target path `wiki/archives/<year>/<Page Name>.md` (year = today's), the index bullet that will move, the `address_map` key if present, and the note that backlinks keep working. Refuse spine files, folds, and `_index.md` (same refusals as wiki-delete).
2. On confirm:
   1. `mkdir -p wiki/archives/<year>/` and `mv` the page there (Bash).
   2. `Edit` the page frontmatter: `status: archived`, bump `updated:`.
   3. `Edit` `wiki/index.md`: move the bullet out of its section into an `## Archived` section (create if missing). Do NOT decrement "Total pages" — the page still exists.
   4. Update `.raw/.manifest.json` `address_map`: re-key the entry from the old path to the new path (the documented rename rule; same sanctioned-exception rationale as wiki-delete step 4.3).
   5. `Edit` `wiki/log.md`: prepend an `archive` entry (location old → new, reason).
3. Aftermath (say, don't do): `hot.md` self-corrects next overwrite; tiling cache re-keys itself on next run (old path GC'd, new path embedded — content hash unchanged means no re-POST); retrieval chunks re-index later.

Archived pages are exempt from staleness aging (see wiki-lint §Staleness Aging) and keep their address — archiving is a rename, not a retirement of identity.

---

## Tier 2 — Archive a cold raw source

For `.raw/` files that were **already ingested** and are just inbox clutter. The knowledge lives in `wiki/`; the raw file is the audit trail, so it moves — never deleted, and the pointer follows it.

1. **Plan (stdout)**: confirm the file appears in `.raw/.manifest.json` `sources` (i.e. it was ingested — warn and stop if not: an un-ingested file is pending work, not clutter). Show: target path `.archive/<same relative layout>`, the source page whose `raw_file:`/`sources:` pointer will be updated, the manifest key rename.
2. On confirm:
   1. `mkdir -p` the mirrored folder under `.archive/` and `mv` the file (Bash).
   2. `Edit` the source page: update `raw_file:` (and any `"[[.raw/...]]"` entry in `sources:`) to the new `.archive/...` path; bump `updated:`.
   3. Update `.raw/.manifest.json`: re-key the `sources` entry to the new path (hash and history preserved).
   4. `Edit` `wiki/log.md`: prepend an `archive` entry.
3. Result: `.raw/` stays a clean inbox of pending/live material; provenance never dangles (wiki-lint's Provenance Integrity check stays green).

---

## Tier 3 — The cold vault (manual; print, never drive)

For material that should leave the live brain entirely. This skill **only prints these steps** — it never touches a second vault:

```
1. Create the archive vault once: a plain folder, its own git repo.
   Open it in Obsidian via "Open another vault" if you want it browsable.
   NEVER install the Local REST API plugin there — the live vault's MCP
   owns port 27124, and a passive vault must stay passive.
2. Move the material with Finder or git mv, then commit both vaults.
3. Accept the trade: no MCP, no wiki-query, no lint over there.
   Backlinks to moved pages in the live vault WILL go dead — run
   wiki-delete first if you want reconciled removal, or accept lint flags.
```

---

## Invariants

1. **Plan before move.** No mutation before explicit confirmation.
2. **Archive ≠ delete.** Nothing is ever removed in tiers 1–2; every move keeps its bookkeeping consistent in the same pass.
3. **Pointers follow files.** No `raw_file:`, `sources:`, or `address_map` record may dangle after a commit.
4. **Counters stay honest.** "Total pages" unchanged by a page archive (it still exists); index bullet relocates instead.
5. **log.md is append-only.** Archives are logged forward.
6. **No chaining**; and never touch `wiki/hot.md`.

---

## What NOT to do

- Do not Write/Edit during the plan. Bash stdout only.
- Do not rewrite backlinks for a tier-1 page archive — filename links survive the move.
- Do not archive un-ingested `.raw/` files (that's pending work; tell the user to ingest or delete deliberately).
- Do not delete anything, anywhere, in any tier.
- Do not touch a second vault, install plugins there, or register transports for it.
- Do not suppress the PostToolUse auto-commit hook.

---

## How to think (10-principle mapping)

When working on this skill, apply the 10-principle loop. See [`skills/think/SKILL.md`](../think/SKILL.md) for the canonical framework.

| # | Principle | Application here |
|---|-----------|-------------------|
| 1 | OBSERVE (ext) | Find every path-keyed record before moving: index, address_map, raw_file, sources:. |
| 2 | OBSERVE (int) | Am I about to "helpfully" rewrite backlinks that don't need it? Filename links survive moves. |
| 3 | LISTEN | Did the user mean retire-but-keep (archive) or remove (wiki-delete)? Ask if ambiguous. |
| 4 | THINK | Which tier is this? Page, raw source, and cold vault have different procedures. |
| 5 | CONNECT (lat) | A source being archived often signals its topic went cold — worth mentioning, not acting on. |
| 6 | CONNECT (sys) | Provenance Integrity (lint) + manifest + address_map form one system; a move must keep all green. |
| 7 | FEEL | Archiving should feel like exhaling, not amputating. Nothing is lost; everything is findable. |
| 8 | ACCEPT | The cold vault's trade-offs (no MCP/query/lint) are the user's to accept; print them plainly. |
| 9 | CREATE | A logged, reconciled move with zero dangling pointers. |
| 10 | GROW | If .raw/ refills fast, suggest a periodic archive habit — not an automatic sweep. |
