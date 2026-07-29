# claude-obsidian Hooks

Plugin hooks are machine-global, so all command handlers dispatch through the
trusted `${CLAUDE_PLUGIN_ROOT}/scripts/vault-hook.sh` script. The dispatcher
resolves `${CLAUDE_PROJECT_DIR}`, verifies a canonical vault marker (or the
strict pre-1.9.5 scaffold signature), and never executes project-controlled
scripts.

| Event | Purpose |
|---|---|
| `SessionStart` | Emit `wiki/hot.md` and clear stale locks through the bundled `wiki-lock.sh`. |
| `PostCompact` | Re-emit the hot cache; a signature-aware prompt remains as fallback for Claude Code versions that drop plugin-hook stdout. |
| `PostToolUse` | Auto-commit only `wiki/`, `.raw/`, and `.vault-meta/`, unless the kill switch exists or a lock is active. |
| `Stop` | Emit the factual hot-cache refresh reminder when wiki files remain changed. |

## Vault signature

`bin/setup-vault.sh` idempotently creates:

```json
{"schema": 1, "kind": "claude-obsidian-vault"}
```

at `.vault-meta/claude-obsidian-vault.json`. Existing vaults remain active via
a strict signature requiring `.obsidian/`, `.raw/`, `_templates/`, and all
three spine files `wiki/index.md`, `wiki/log.md`, and `wiki/hot.md`.

## Hook stdout compatibility

`anthropics/claude-code#10875` documents versions where plugin-hook stdout may
not reach context. PostCompact therefore retains a prompt fallback, but it is
instructed to read `wiki/hot.md` only after the same vault-signature check.

Run `bash tests/test_vault_hook.sh` to verify confinement and compatibility.
