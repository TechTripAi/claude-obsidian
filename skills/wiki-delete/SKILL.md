---
name: wiki-delete
description: "Safe page deletion for the wiki vault. Deleting a page by hand strands backlinks, index entries, the page counter, and manifest records — this skill reconciles all of them in one guided flow. Impact report first (dry-run, stdout-only), then per-reference decisions, then a logged, hook-committed delete. Triggers on: delete this page, remove from the wiki, wiki delete, safe delete, retire this page, get rid of this page."
---

# wiki-delete: Safe Page Deletion

"`wiki/` is yours. Create, update, rename, delete freely" is **permission, not procedure**. A bare `rm` leaves dead wikilinks in other pages, a stale bullet and a wrong "Total pages" count in `wiki/index.md`, orphaned `pages_created`/`address_map` records in `.raw/.manifest.json` — rot that the next lint has to rediscover. This skill is the procedure: **show the full blast radius first, get consent, then reconcile everything the deletion touches.**

Deletion is destructive and judgment-heavy. **Never chain into this skill** — it runs only when the user explicitly asks to delete a page, and never deletes more than the pages they named.

---

## Scope boundary (explicit)

This skill does:
- Delete one wiki page (or a small named set) with full reference reconciliation.
- Reconcile: inbound backlinks, `wiki/index.md` (+ any `_index.md` sub-index), the index counter line, `.raw/.manifest.json` (`pages_created`/`pages_updated` lists, `address_map` key).
- Log the deletion forward in `wiki/log.md`.

This skill does NOT:
- Delete fold pages — that is wiki-fold's documented **Reversal** procedure; defer to [`skills/wiki-fold/SKILL.md`](../wiki-fold/SKILL.md) §Reversal.
- Delete the vault spine: `index.md`, `log.md`, `hot.md`, `overview.md`, any `_index.md`. Refuse these by name.
- Delete raw files under `.raw/` — sources are immutable inputs. If the target is a source page, its raw file **stays put** (say so in the report; archiving cold raw files is wiki-archive territory).
- Batch-sweep "everything matching X". Explicit page names only.

---

## Modes

| Mode | Writes? | Invocation |
|---|---|---|
| **impact report (default)** | **No Write/Edit calls, no rm.** Emit the blast-radius report via Bash stdout only. | `delete [[Page]]` (first response is always the report) |
| **commit** | Uses Edit/Write/Bash rm. Each Edit fires the PostToolUse hook which auto-commits. Accept this. | Only after the user confirms the report with an explicit "yes, delete it" |

**Why stdout-only for the report**: same rationale as wiki-fold — the PostToolUse hook fires on any Write|Edit and runs `git add wiki/ .raw/`, committing *any pending wiki changes*. The report must leave zero residue.

---

## Concurrency (v1.7+)

Commit mode MUST hold the lock on every file it edits, per the semantics in `skills/wiki-ingest/SKILL.md` §Concurrency:

```bash
for f in "$TARGET_PAGE" "wiki/index.md" "wiki/log.md"; do
  bash scripts/wiki-lock.sh acquire "$f" || {
    echo "FAIL: another writer holds $f; aborting delete."; exit 75
  }
done
# … reconcile + delete …
for f in "$TARGET_PAGE" "wiki/index.md" "wiki/log.md"; do
  bash scripts/wiki-lock.sh release "$f"
done
```

The impact report acquires no locks (no writes happen).

---

## Procedure

### 1. Resolve and classify the target

- Resolve the page path (transport policy: `obsidian-cli`, MCP, or filesystem — same decision tree as wiki-lint).
- **Refuse** spine files and fold pages (see Scope boundary). For folds, hand the user wiki-fold's Reversal steps instead.
- Note the page's `type:` — a `type: source` page gets the raw-file callout in the report (step 2).

### 2. Build the impact report (stdout only)

Gather, without writing anything:

- **Inbound backlinks**: `obsidian-cli backlinks "$VAULT" "$NOTE"` when transport is cli; otherwise Grep for `[[Page Name]]` across `wiki/` (bodies AND `related:`/`sources:` frontmatter).
- **Index entries**: the page's bullet in `wiki/index.md` and any `_index.md` sub-index; the current "Total pages" (and "Sources ingested", if applicable) counter values.
- **Manifest records**: occurrences in `.raw/.manifest.json` — `sources.*.pages_created`, `sources.*.pages_updated`, and its `address_map` key if present.
- **Raw file** (source pages only): the `raw_file:`/`sources:` provenance target. It will NOT be deleted.

Emit:

```markdown
# Delete impact: [[Page Name]] (wiki/concepts/Page Name.md)

## Inbound references (N)
- [[Page A]] — 2 body links, 1 related: entry
- [[Page B]] — 1 body link

## Bookkeeping
- index.md: bullet under "## Concepts"; Total pages 34 → 33
- .raw/.manifest.json: listed in pages_created of `.raw/articles/foo.md`; address_map key `wiki/concepts/Page Name.md` → c-000017

## Stays untouched
- .raw/articles/foo.md (raw source is immutable; archive separately if cold)
- log.md history mentioning this page (append-only — history is never scrubbed)
- hot.md (overwritten on next ingest; a stale mention until then is expected)

Proceed? For each inbound reference: rewrite to another page, remove the link, or leave it (lint will flag it as dead).
```

**Stop here.** Do not proceed without an explicit confirmation.

### 3. Per-reference decisions

For each referencing page, the user picks: **rewrite** (point the link at a named replacement page), **remove** (unlink the text, keep the prose), or **leave** (accept a dead link; wiki-lint will keep flagging it). Batch-apply one answer ("remove all") only if the user says so.

### 4. Reconcile (commit mode, in this order)

1. Apply the per-reference edits from step 3.
2. `Edit` `wiki/index.md`: remove the page's bullet; decrement the "Total pages" counter (and "Sources ingested" for a source page whose bullet lived there). Same for any `_index.md`.
3. Update `.raw/.manifest.json`: remove the page from every `pages_created`/`pages_updated` list and delete its `address_map` key. This is the one sanctioned exception to "wiki-ingest maintains the manifest" — a reconciling delete must not leave orphaned records. Preserve JSON structure exactly; do not touch unrelated entries.
4. `rm` the page file via Bash. (Bash does not fire the auto-commit hook — that is intentional; the next step's Edit sweeps the deletion into its commit, since the hook runs `git add wiki/ .raw/`.)
5. `Edit` `wiki/log.md` to prepend the delete entry (append-only is preserved — deletions are **logged forward**, never scrubbed backward):
   ```
   ## [YYYY-MM-DD] delete | Page Name
   - Location: wiki/concepts/Page Name.md (removed)
   - Inbound refs: N (X rewritten, Y removed, Z left dead)
   - Reason: <user's one-liner>
   ```

### 5. Aftermath notes (say, don't do)

- `wiki/hot.md`: owned by save/ingest; it self-corrects on next overwrite. Do not edit it.
- Tiling cache (`.vault-meta/tiling-cache.json`): self-GCs the deleted path on next tiling run. No action.
- Hybrid-retrieval caches (BM25/embedding chunks, if `setup-retrieve.sh` was run): may hold stale chunks until the next re-index. Mention it; do not rebuild unasked.

---

## Invariants

1. **Report before removal.** No mutation of any kind before the user confirms the impact report.
2. **Named pages only.** Never widen scope beyond what the user explicitly listed.
3. **log.md is append-only.** A deletion adds an entry; it never rewrites history.
4. **Raw files survive.** `.raw/` is immutable input; this skill never deletes there.
5. **Counter honesty.** index counters are decremented in the same commit that drops the bullet.
6. **No chaining**: wiki-delete does not invoke lint, ingest, fold, or archive on its own.

---

## What NOT to do

- Do not Write/Edit during the impact report. Bash stdout only.
- Do not delete spine files, `_index.md` files, or fold pages (folds → wiki-fold Reversal).
- Do not scrub the deleted page out of old `log.md` entries or folds.
- Do not touch `wiki/hot.md`.
- Do not "helpfully" delete the raw source alongside a source page.
- Do not suppress or bypass the PostToolUse auto-commit hook.

---

## How to think (10-principle mapping)

When working on this skill, apply the 10-principle loop. See [`skills/think/SKILL.md`](../think/SKILL.md) for the canonical framework.

| # | Principle | Application here |
|---|-----------|-------------------|
| 1 | OBSERVE (ext) | Find EVERY inbound reference — bodies, related:, sources:, sub-indexes. A missed one becomes silent rot. |
| 2 | OBSERVE (int) | Deletion feels tidy; am I underweighting what breaks? The report exists to counter that bias. |
| 3 | LISTEN | The user asked to delete a page, not a cluster. Scope stays exactly what they named. |
| 4 | THINK | Order matters: refs → index → manifest → rm → log, so the hook commit sweeps cleanly. |
| 5 | CONNECT (lat) | A page with heavy inbound links is a merge candidate, not a delete candidate — say so. |
| 6 | CONNECT (sys) | index counter + manifest + address_map + caches are one system; reconcile all or none. |
| 7 | FEEL | Deletion is irreversible-feeling even under git. The report gives the user a calm, informed yes. |
| 8 | ACCEPT | "Leave it dead" is a legitimate per-reference answer; lint exists to catch it later. |
| 9 | CREATE | One logged, hook-committed deletion with zero stranded records. |
| 10 | GROW | Repeated deletes from the same folder hint at an ingestion-quality problem upstream — mention it once. |
