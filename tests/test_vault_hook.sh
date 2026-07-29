#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/scripts/vault-hook.sh"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/vault-hook-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# A generic wiki/ repository is not a vault and contributes no hook output.
NONVAULT="$SANDBOX/nonvault"
mkdir -p "$NONVAULT/wiki" "$NONVAULT/scripts"
printf 'untrusted hot cache\n' > "$NONVAULT/wiki/hot.md"
printf '#!/bin/sh\ntouch "%s/pwned"\n' "$SANDBOX" > "$NONVAULT/scripts/wiki-lock.sh"
chmod +x "$NONVAULT/scripts/wiki-lock.sh"
[ -z "$(CLAUDE_PROJECT_DIR="$NONVAULT" "$HOOK" session-start)" ] || fail "generic wiki repo activated"
[ ! -e "$SANDBOX/pwned" ] || fail "project-controlled wiki-lock executed"

# A canonical marker activates hot-cache output, but still never executes the
# project-controlled script of the same name.
VAULT="$SANDBOX/vault"
mkdir -p "$VAULT/.obsidian" "$VAULT/.raw" "$VAULT/wiki" "$VAULT/.vault-meta" "$VAULT/scripts"
printf '{"schema":1,"kind":"claude-obsidian-vault"}\n' > "$VAULT/.vault-meta/claude-obsidian-vault.json"
printf 'trusted hot cache\n' > "$VAULT/wiki/hot.md"
cp "$NONVAULT/scripts/wiki-lock.sh" "$VAULT/scripts/wiki-lock.sh"
[ "$(CLAUDE_PROJECT_DIR="$VAULT" "$HOOK" post-compact)" = "trusted hot cache" ] || fail "canonical vault did not activate"
CLAUDE_PROJECT_DIR="$VAULT" "$HOOK" session-start >/dev/null
[ ! -e "$SANDBOX/pwned" ] || fail "canonical vault executed project-controlled wiki-lock"

# The complete pre-1.9.5 scaffold remains compatible without a marker.
LEGACY="$SANDBOX/legacy"
mkdir -p "$LEGACY/.obsidian" "$LEGACY/.raw" "$LEGACY/_templates" "$LEGACY/wiki"
printf 'index\n' > "$LEGACY/wiki/index.md"
printf 'log\n' > "$LEGACY/wiki/log.md"
printf 'legacy hot\n' > "$LEGACY/wiki/hot.md"
[ "$(CLAUDE_PROJECT_DIR="$LEGACY" "$HOOK" post-compact)" = "legacy hot" ] || fail "legacy vault did not activate"

# Auto-commit remains path-scoped and the kill switch remains effective.
git -C "$VAULT" init -q
git -C "$VAULT" config user.email test@example.com
git -C "$VAULT" config user.name "Hook Test"
git -C "$VAULT" add -- wiki/ .raw/ .vault-meta/
git -C "$VAULT" commit -qm baseline
printf 'changed\n' >> "$VAULT/wiki/hot.md"
CLAUDE_PROJECT_DIR="$VAULT" "$HOOK" post-tool-use
git -C "$VAULT" log -1 --format=%s | grep -q '^wiki: auto-commit ' || fail "wiki change not committed"
touch "$VAULT/.vault-meta/auto-commit.disabled"
printf 'disabled\n' >> "$VAULT/wiki/hot.md"
CLAUDE_PROJECT_DIR="$VAULT" "$HOOK" post-tool-use
git -C "$VAULT" diff --quiet -- wiki/hot.md && fail "kill switch did not preserve change"

echo "All vault-hook tests passed."
