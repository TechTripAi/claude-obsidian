#!/usr/bin/env bash
# claude-obsidian: multi-agent skill installer
# Symlinks the skills/ directory into each AI agent's expected location.
# Idempotent: safe to run multiple times.
#
# Supported agents:
#   - Claude Code    : auto-discovered via .claude-plugin/ (no symlink needed)
#   - Codex CLI      : symlink to ~/.codex/skills/claude-obsidian
#   - OpenCode       : symlink to ~/.opencode/skills/claude-obsidian
#   - Gemini CLI     : symlink to ~/.gemini/skills/claude-obsidian
#   - Cursor         : symlink to .cursor/skills (in repo)
#   - Windsurf       : symlink to .windsurf/skills (in repo)
#
# Bootstrap files (AGENTS.md, GEMINI.md, .cursor/rules/, .windsurf/rules/,
# .github/copilot-instructions.md) are already committed in the repo.
# This script just wires up the skills directory.
#
# The home-directory links (~/.codex, ~/.opencode, ~/.gemini) write outside
# this repo, so they are consent-gated: the script asks first when a terminal
# is attached, --yes skips the question, and a non-interactive run without
# --yes skips the links and prints the ln -s commands instead. The repo-local
# links (.cursor/, .windsurf/) are project-owned and never prompt.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=true ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "ERR: unknown flag: $arg" >&2; exit 2 ;;
  esac
done

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: $SKILLS_DIR does not exist. Are you running this from the claude-obsidian repo?"
  exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
GRAY='\033[0;37m'
NC='\033[0m'

link_if_missing() {
  local target="$1"
  local dest="$2"
  local agent_name="$3"

  mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ]; then
    local existing="$(readlink "$dest")"
    if [ "$existing" = "$target" ]; then
      echo -e "${GRAY}[$agent_name] already linked: $dest${NC}"
      return
    else
      echo -e "${YELLOW}[$agent_name] symlink exists but points elsewhere: $dest -> $existing (skipping, remove manually if you want to relink)${NC}"
      return
    fi
  fi

  if [ -e "$dest" ]; then
    echo -e "${YELLOW}[$agent_name] path exists and is not a symlink: $dest (skipping)${NC}"
    return
  fi

  ln -s "$target" "$dest"
  echo -e "${GREEN}[$agent_name] linked: $dest -> $target${NC}"
}

echo "claude-obsidian: multi-agent skill installer"
echo "Repo: $REPO_ROOT"
echo

# Home-directory links write outside the repo — ask first.
HOME_LINKS_OK=false
if $ASSUME_YES; then
  HOME_LINKS_OK=true
elif [ -t 0 ]; then
  printf "Link skills into ~/.codex, ~/.opencode, ~/.gemini? [Y/n] "
  read -r reply
  case "$reply" in
    [nN]|[nN][oO]) HOME_LINKS_OK=false ;;
    *)             HOME_LINKS_OK=true ;;
  esac
else
  echo "No terminal to ask on — skipping the home-directory links."
fi

if $HOME_LINKS_OK; then
  # Codex CLI
  link_if_missing "$SKILLS_DIR" "$HOME/.codex/skills/claude-obsidian" "Codex CLI"

  # OpenCode
  link_if_missing "$SKILLS_DIR" "$HOME/.opencode/skills/claude-obsidian" "OpenCode"

  # Gemini CLI
  link_if_missing "$SKILLS_DIR" "$HOME/.gemini/skills/claude-obsidian" "Gemini CLI"
else
  echo "Skipped home-directory links. Create them yourself with:"
  echo "  ln -s $SKILLS_DIR $HOME/.codex/skills/claude-obsidian"
  echo "  ln -s $SKILLS_DIR $HOME/.opencode/skills/claude-obsidian"
  echo "  ln -s $SKILLS_DIR $HOME/.gemini/skills/claude-obsidian"
  echo "or re-run with --yes."
fi

# Cursor (workspace-local)
link_if_missing "$SKILLS_DIR" "$REPO_ROOT/.cursor/skills" "Cursor"

# Windsurf (workspace-local)
link_if_missing "$SKILLS_DIR" "$REPO_ROOT/.windsurf/skills" "Windsurf"

echo
echo -e "${GREEN}Done.${NC} Bootstrap files (AGENTS.md, GEMINI.md, .cursor/rules/, .windsurf/rules/, .github/copilot-instructions.md) are already in this repo."
echo
echo "To verify each agent picks up the skills:"
echo "  - Claude Code: open the project, type /wiki"
echo "  - Codex CLI:   codex --list-skills | grep claude-obsidian"
echo "  - Cursor:      open the project, ask 'what skills do you have?'"
echo "  - Windsurf:    open in Cascade, ask the same"
echo "  - Gemini CLI:  gemini --list-skills (if supported)"
