# Install consent: preserve user Obsidian config, target the real vault from the plugin cache

Proposal writeup for the two behavior-changing 1.9.6 fixes (the other two
1.9.6 changes — the Excalidraw/home-symlink consent gates and the
instruct-then-offer docs — ride along and need no pitch beyond their
CHANGELOG entries).

## 1. setup-vault.sh clobbers user Obsidian config

### Summary

`bin/setup-vault.sh` rewrites `.obsidian/graph.json`, `app.json`, and
`appearance.json` unconditionally (`cat > … <<EOF`, no existence check). The
script is documented as idempotent and is re-run by orchestrators and
updates, so any user-tuned graph colors, ignore filters, or CSS snippet
selections are silently destroyed on the second run.

### Reproduction

1. Run `bash bin/setup-vault.sh /path/to/vault`.
2. In Obsidian, change a graph color group (writes `.obsidian/graph.json`).
3. Run `bash bin/setup-vault.sh /path/to/vault` again.
4. The customization is gone — the file is back to the shipped template.

### Fix

Each of the three `cat >` blocks gets the same write-if-absent guard the
vault marker (`.vault-meta/claude-obsidian-vault.json`) already uses. An
existing file is reported and left untouched; deleting it and re-running
regenerates it.

### Compatibility

First runs are byte-identical to before. Re-runs change behavior only in
the case that was previously destructive.

## 2. setup-retrieve.sh / setup-mode.sh provision the plugin cache

### Summary

Both scripts hard-wire `VAULT` to their own parent directory
(`dirname $SCRIPT_DIR`) and reject unknown arguments. When claude-obsidian
is installed as a Claude Code plugin, the scripts live in
`~/.claude/plugins/cache/<marketplace>/claude-obsidian/<version>/bin/`, so
running them provisions the cache copy — `.vault-meta/chunks/`, `bm25/`,
`mode.json` all land in the cache, not the user's vault. The failure is
silent: the cache ships a fully-populated demo `wiki/`, so everything
appears to succeed.

### Reproduction

1. `claude plugin install claude-obsidian`.
2. `bash ~/.claude/plugins/cache/*/claude-obsidian/*/bin/setup-retrieve.sh --check`
3. Observe `Vault: ~/.claude/plugins/cache/...` — diagnostics and any
   provisioning target the cache.

### Fix

- New `--vault PATH` flag on both scripts (default unchanged: the script's
  parent, i.e. a repo checkout keeps working with no arguments).
- Refuse any target that resolves inside `~/.claude/plugins/` — the demo
  `wiki/` makes the cache look vault-shaped, so the path itself is checked.
- Require the target to be vault-shaped (`wiki/` or `.vault-meta/` present).

### Compatibility

Repo-checkout invocations are unchanged. The only newly-refused case
(running against the plugin cache) was always a bug.

## Verification

- `bash -n` on all touched scripts.
- setup-vault run twice into a temp vault with an edited `graph.json`
  between runs → "exists — left untouched", customization preserved.
- `setup-vault.sh </dev/null` → Excalidraw download skipped, manual curl
  printed; `--with-excalidraw` downloads unprompted.
- `setup-retrieve.sh --vault /tmp/not-a-vault --check` → refused (exit 2);
  `--vault <cache path> --check` → refused; `--vault <real vault> --check`
  → diagnostics run against that path; no flags from a repo checkout →
  unchanged.
- `make test` green.
