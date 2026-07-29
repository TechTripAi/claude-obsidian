#!/usr/bin/env bash
# Trusted dispatcher for claude-obsidian's machine-global plugin hooks.
#
# Hook code must come from CLAUDE_PLUGIN_ROOT, never from the current project:
# any repository can contain a scripts/wiki-lock.sh. The project contributes
# data only after it passes the vault signature check below.
set -uo pipefail

ACTION="${1:-}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

if ! PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P)"; then
  exit 0
fi

is_canonical_vault() {
  local marker="$PROJECT_ROOT/.vault-meta/claude-obsidian-vault.json"
  [ -d "$PROJECT_ROOT/.obsidian" ] &&
    [ -d "$PROJECT_ROOT/.raw" ] &&
    [ -d "$PROJECT_ROOT/wiki" ] &&
    [ -f "$marker" ] &&
    grep -Eq '"kind"[[:space:]]*:[[:space:]]*"claude-obsidian-vault"' "$marker" 2>/dev/null &&
    grep -Eq '"schema"[[:space:]]*:[[:space:]]*1([,}[:space:]]|$)' "$marker" 2>/dev/null
}

is_legacy_vault() {
  # Backward-compatible signature for vaults created before 1.9.5. Requiring
  # the complete spine is intentionally stricter than the old generic wiki/.
  [ -d "$PROJECT_ROOT/.obsidian" ] &&
    [ -d "$PROJECT_ROOT/.raw" ] &&
    [ -d "$PROJECT_ROOT/_templates" ] &&
    [ -f "$PROJECT_ROOT/wiki/index.md" ] &&
    [ -f "$PROJECT_ROOT/wiki/log.md" ] &&
    [ -f "$PROJECT_ROOT/wiki/hot.md" ]
}

is_canonical_vault || is_legacy_vault || exit 0

emit_hot_cache() {
  [ -f "$PROJECT_ROOT/wiki/hot.md" ] && cat "$PROJECT_ROOT/wiki/hot.md" || true
}

case "$ACTION" in
  session-start)
    emit_hot_cache
    if [ -x "$PLUGIN_ROOT/scripts/wiki-lock.sh" ]; then
      WIKI_LOCK_VAULT="$PROJECT_ROOT" \
        bash "$PLUGIN_ROOT/scripts/wiki-lock.sh" clear-stale --max-age 3600 \
        >/dev/null 2>&1 || true
    fi
    ;;
  post-compact)
    emit_hot_cache
    ;;
  post-tool-use)
    git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0
    [ -f "$PROJECT_ROOT/.vault-meta/auto-commit.disabled" ] && exit 0
    if [ -x "$PLUGIN_ROOT/scripts/wiki-lock.sh" ]; then
      LOCK_LIST="$(WIKI_LOCK_VAULT="$PROJECT_ROOT" \
        bash "$PLUGIN_ROOT/scripts/wiki-lock.sh" list 2>/dev/null)"
      LOCK_RC=$?
      if [ "$LOCK_RC" != "0" ]; then
        mkdir -p "$PROJECT_ROOT/.vault-meta" 2>/dev/null
        printf '%s wiki-lock list failed rc=%s; deferred auto-commit\n' \
          "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$LOCK_RC" \
          >> "$PROJECT_ROOT/.vault-meta/hook.log" 2>/dev/null
        exit 0
      fi
      [ -n "$LOCK_LIST" ] && exit 0
    fi
    hook_paths=(wiki/ .raw/ .vault-meta/)
    git -C "$PROJECT_ROOT" add -- "${hook_paths[@]}" 2>/dev/null || exit 0
    # `git commit -- <paths>` rejects an existing-but-empty directory. Commit
    # only scopes that now contain tracked/staged files, while still excluding
    # unrelated user-staged changes.
    commit_paths=()
    for rel in "${hook_paths[@]}"; do
      if git -C "$PROJECT_ROOT" ls-files -- "$rel" | grep -q .; then
        commit_paths+=("$rel")
      fi
    done
    [ "${#commit_paths[@]}" -gt 0 ] || exit 0
    if ! git -C "$PROJECT_ROOT" diff --cached --quiet -- "${commit_paths[@]}"; then
      git -C "$PROJECT_ROOT" commit \
        -m "wiki: auto-commit $(date '+%Y-%m-%d %H:%M')" \
        -- "${commit_paths[@]}" >/dev/null 2>&1 || true
    fi
    ;;
  stop)
    git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0
    if git -C "$PROJECT_ROOT" diff --name-only HEAD -- wiki/ 2>/dev/null \
      | grep -q '^wiki/'; then
      printf '%s\n' 'WIKI_CHANGED: Wiki pages were modified this session. Please update wiki/hot.md with a brief summary of what changed (under 500 words). Use the hot cache format: Last Updated, Key Recent Facts, Recent Changes, Active Threads. Keep it factual. Overwrite the file completely. It is a cache, not a journal.'
    fi
    ;;
  *) exit 0 ;;
esac

exit 0
