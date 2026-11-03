# Vendored code

This fork stays on the claude-obsidian 1.9.x architecture (shell hooks, auto-commit,
advisory locks). Where upstream 3.x has a self-contained component worth having, it is
copied in verbatim rather than cherry-picked, so it can be re-synced by copying files.

## Deterministic lint engine

| | |
|---|---|
| Upstream | https://github.com/AgriciDaniel/claude-obsidian |
| Upstream commit | `2e545563172f97f02ecaaaab376ceea1246a0583` (`upstream/main` on 2026-10-22; three docs-only merges after the `v3.0.1` tag at `6414e1a`) |
| Vendored on | 2026-11-02 (fork 1.9.7) |
| License | MIT (upstream author Daniel Agrici; see ATTRIBUTION.md) |
| Python floor | 3.11 |

Files, copied byte-for-byte from `claude_obsidian/` upstream into `scripts/claude_obsidian/`:

```
__init__.py  gitignore.py  json_utils.py  ledgers.py  limits.py  lint_engine.py
markdown_links.py  page_schema.py  paths.py  transaction.py  url_safety.py  visible_paths.py
```

`transaction.py` and `ledgers.py` are pulled in only because `lint_engine.py` lazily
imports a bounded no-follow file reader, an error type, a size limit, and the ledger
validators from them. Nothing in this fork invokes upstream's transactional write path.

Also copied: `tests/test_lint_engine.py` and `tests/fixtures/lint/`. The test file carries
three local edits (sys.path points at `scripts/`, `ENGINE_PATH` points at the vendored
location, and the four CLI subprocess calls target `scripts/wiki-lint.py` instead of
`scripts/claude-obsidian.py lint`).

Fork-owned, not vendored: `scripts/wiki-lint.py` (the CLI wrapper) and
`tests/test_wiki_lint_cli.py`. The wrapper deliberately differs from upstream's
`claude-obsidian lint` in one default: `--format` is `markdown` here (upstream: `json`),
because the agent-facing skill wants the human report by default. JSON output matches
upstream's serializer (`sort_keys=True, ensure_ascii=False`, two-space indent).

### Re-sync

```bash
git fetch upstream
for m in __init__ gitignore json_utils ledgers limits lint_engine markdown_links \
         page_schema paths transaction url_safety visible_paths; do
  git show upstream/main:claude_obsidian/$m.py > scripts/claude_obsidian/$m.py
done
git show upstream/main:tests/test_lint_engine.py > tests/test_lint_engine.py
# fixtures: remove the old tree first so files upstream deleted do not linger
rm -r tests/fixtures/lint
git archive upstream/main tests/fixtures/lint | tar -x -C .
# re-apply the three test edits listed above, then:
make test-lint
```

Update the commit SHA and date in the table above when you do.
