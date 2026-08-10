#!/usr/bin/env bash
# claude-obsidian vault setup script
# Run this ONCE before opening Obsidian for the first time.
# Usage: bash bin/setup-vault.sh [optional: /path/to/vault] [--with-excalidraw|--no-excalidraw]
# Default: uses the directory where this script lives (the vault root)
#
# Existing .obsidian/*.json config is never overwritten — delete a file and
# re-run to regenerate it. The Excalidraw main.js download (~8MB from GitHub,
# latest release, unpinned) is consent-gated: pass --with-excalidraw to
# download without prompting, --no-excalidraw to skip; with neither flag the
# script asks when a terminal is attached and skips otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT=""
EXCALIDRAW_MODE="ask"   # ask | yes | no
for arg in "$@"; do
  case "$arg" in
    --with-excalidraw) EXCALIDRAW_MODE="yes" ;;
    --no-excalidraw)   EXCALIDRAW_MODE="no" ;;
    -*)
      echo "Unknown option: $arg" >&2
      echo "Usage: bash bin/setup-vault.sh [/path/to/vault] [--with-excalidraw|--no-excalidraw]" >&2
      exit 2 ;;
    *)                 VAULT="$arg" ;;
  esac
done
[ -n "$VAULT" ] || VAULT="$(dirname "$SCRIPT_DIR")"
OBSIDIAN="$VAULT/.obsidian"

echo "Setting up claude-obsidian vault at: $VAULT"

# ── 1. Create directories ─────────────────────────────────────────────────────
mkdir -p "$OBSIDIAN/snippets"
mkdir -p "$VAULT/.raw"
mkdir -p "$VAULT/wiki/concepts" "$VAULT/wiki/entities" "$VAULT/wiki/sources" "$VAULT/wiki/meta"
mkdir -p "$VAULT/_templates"
mkdir -p "$VAULT/.vault-meta"

# Machine-global plugin hooks must distinguish a real vault from an unrelated
# repository that happens to contain wiki/. Seed a stable, content-free marker;
# never overwrite a future schema or user-edited file.
VAULT_MARKER="$VAULT/.vault-meta/claude-obsidian-vault.json"
if [ ! -e "$VAULT_MARKER" ]; then
  cat > "$VAULT_MARKER" <<'EOF'
{
  "schema": 1,
  "kind": "claude-obsidian-vault"
}
EOF
fi

# ── 2. Write graph.json ───────────────────────────────────────────────────────
if [ -e "$OBSIDIAN/graph.json" ]; then
  echo "✓ graph.json exists — left untouched (delete it and re-run to regenerate)"
else
cat > "$OBSIDIAN/graph.json" << 'EOF'
{
  "collapse-filter": false,
  "search": "path:wiki",
  "showTags": false,
  "showAttachments": false,
  "hideUnresolved": true,
  "showOrphans": false,
  "collapse-color-groups": false,
  "colorGroups": [
    { "query": "path:wiki/entities",    "color": { "a": 1, "rgb": 12945088 } },
    { "query": "path:wiki/concepts",    "color": { "a": 1, "rgb": 5227007  } },
    { "query": "path:wiki/sources",     "color": { "a": 1, "rgb": 6986069  } },
    { "query": "path:wiki/meta",        "color": { "a": 1, "rgb": 5676246  } },
    { "query": "path:wiki",             "color": { "a": 1, "rgb": 5676246  } }
  ],
  "showArrow": true,
  "textFadeMultiplier": -1,
  "nodeSizeMultiplier": 1.8,
  "lineSizeMultiplier": 1.2,
  "centerStrength": 0.5,
  "repelStrength": 30,
  "linkStrength": 1.5,
  "linkDistance": 120,
  "scale": 1.0
}
EOF
fi

# ── 3. Write app.json (excluded files) ───────────────────────────────────────
if [ -e "$OBSIDIAN/app.json" ]; then
  echo "✓ app.json exists — left untouched (delete it and re-run to regenerate)"
else
cat > "$OBSIDIAN/app.json" << 'EOF'
{
  "userIgnoreFilters": [
    "agents/",
    "commands/",
    "hooks/",
    "skills/",
    "_templates/",
    "README.md",
    "CLAUDE.md",
    "WIKI.md",
    "Welcome.md"
  ]
}
EOF
fi

# ── 4. Write appearance.json (enable CSS snippets) ───────────────────────────
if [ -e "$OBSIDIAN/appearance.json" ]; then
  echo "✓ appearance.json exists — left untouched (delete it and re-run to regenerate)"
else
cat > "$OBSIDIAN/appearance.json" << 'EOF'
{
  "enabledCssSnippets": [
    "vault-colors",
    "ITS-Dataview-Cards",
    "ITS-Image-Adjustments"
  ]
}
EOF
fi

# ── 5. Download Excalidraw main.js (8MB, not in git) ─────────────────────────
EXCALIDRAW="$OBSIDIAN/plugins/obsidian-excalidraw-plugin"
EXCALIDRAW_URL="https://github.com/zsviczian/obsidian-excalidraw-plugin/releases/latest/download/main.js"
if [ -f "$EXCALIDRAW/manifest.json" ] && [ ! -f "$EXCALIDRAW/main.js" ]; then
  if [ "$EXCALIDRAW_MODE" = "ask" ]; then
    if [ -t 0 ]; then
      echo "Excalidraw needs its main.js (~8MB, downloaded from GitHub releases — latest, unpinned):"
      echo "  $EXCALIDRAW_URL"
      printf "Download it now? [y/N] "
      read -r reply
      case "$reply" in
        [yY]|[yY][eE][sS]) EXCALIDRAW_MODE="yes" ;;
        *)                 EXCALIDRAW_MODE="no" ;;
      esac
    else
      EXCALIDRAW_MODE="no"
    fi
  fi
  if [ "$EXCALIDRAW_MODE" = "yes" ]; then
    echo "Downloading Excalidraw main.js (~8MB)..."
    curl -sS -L "$EXCALIDRAW_URL" -o "$EXCALIDRAW/main.js"
    echo "✓ Excalidraw main.js downloaded"
  else
    echo "Skipped Excalidraw main.js. Download it later with:"
    echo "  curl -L $EXCALIDRAW_URL -o $EXCALIDRAW/main.js"
    echo "or re-run this script with --with-excalidraw."
  fi
elif [ -f "$EXCALIDRAW/main.js" ]; then
  echo "✓ Excalidraw main.js already present"
fi

echo ""
echo "✓ Setup complete."
echo ""
echo "Next steps:"
echo "  1. Open Obsidian"
echo "  2. Manage Vaults → Open folder as vault → select: $VAULT"
echo "  3. Enable community plugins when prompted (Calendar, Thino, Excalidraw, Banners are pre-installed)"
echo "  4. Install: Dataview, Templater, Obsidian Git  (Settings → Community Plugins)"
echo "  5. Type /wiki in Claude Code to scaffold your knowledge base"
echo ""
echo "Pre-installed plugins:"
echo "  - Calendar (sidebar calendar with word count + task dots)"
echo "  - Thino (quick memo capture)"
echo "  - Excalidraw (freehand drawing + image annotation)"
echo "  - Banners (add banner: to any note frontmatter for header images)"
echo ""
echo "CSS snippets enabled:"
echo "  - vault-colors: color-codes wiki/ folders in file explorer"
echo "  - ITS-Dataview-Cards: use \`\`\`dataviewjs with .cards for card grids"
echo "  - ITS-Image-Adjustments: append |100 to image embeds for sizing"
echo ""
echo "Views available:"
echo "  - Wiki Map canvas (wiki/Wiki Map.canvas) — knowledge graph"
echo "  - Design Ideas canvas (projects/visual-vault/design-ideas.canvas) — visual reference board"
echo "  - Graph view filtered to wiki/ only, color-coded by type"
echo ""
echo "To switch to the visual layout (Canvas + Calendar + Thino sidebar):"
echo "  Quit Obsidian, then run:"
echo "    cp $OBSIDIAN/workspace-visual.json $OBSIDIAN/workspace.json"
echo "  Then reopen Obsidian."
echo ""
echo "Graph colors: if they reset after closing Obsidian, open Graph settings"
echo "→ Color groups and re-add them once. They persist permanently after that."
