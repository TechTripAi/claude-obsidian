#!/usr/bin/env python3
"""Deterministic, read-only wiki lint for claude-obsidian 1.9.x.

Thin CLI over the lint engine vendored from upstream claude-obsidian 3.0.1
(see VENDORED.md). Every harness (Claude Code, Codex, Copilot, Cursor, ...)
runs this same command, so every harness gets the same report.

Usage:
  python3 scripts/wiki-lint.py --vault /path/to/vault
  python3 scripts/wiki-lint.py --vault /path/to/vault --format markdown
  python3 scripts/wiki-lint.py --vault /path/to/vault --exclude "wiki/scratchpad/*"
  python3 scripts/wiki-lint.py --vault /path/to/vault --strict   # exit 1 on findings

Exit codes: 0 ok (or findings without --strict), 1 findings with --strict,
2 usage/vault error.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

if sys.version_info < (3, 11):
    sys.stderr.write("wiki-lint requires Python 3.11 or newer\n")
    sys.exit(2)

SCRIPTS_DIR = str(Path(__file__).resolve().parent)
if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

from claude_obsidian.lint_engine import lint_vault, render_markdown  # noqa: E402


def _resolve_vault(arg: str | None) -> Path:
    candidate = arg or os.environ.get("CLAUDE_OBSIDIAN_VAULT") or os.getcwd()
    root = Path(candidate).expanduser().resolve()
    if not (root / "wiki").is_dir():
        sys.stderr.write(
            f"wiki-lint: {root} has no wiki/ directory; pass --vault or set CLAUDE_OBSIDIAN_VAULT\n"
        )
        sys.exit(2)
    return root


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="wiki-lint", description="Deterministically inspect an Obsidian wiki vault (read-only)."
    )
    parser.add_argument("--vault", help="vault root (default: $CLAUDE_OBSIDIAN_VAULT or cwd)")
    parser.add_argument("--format", choices=("json", "markdown"), default="markdown")
    parser.add_argument("--as-of", help="ISO YYYY-MM-DD provenance freshness date")
    parser.add_argument(
        "--frontmatter-policy", choices=("presence", "generated"), default=None,
        help="generated-page value checks are opt-in; default follows vault lint configuration",
    )
    parser.add_argument(
        "--exclude", action="append", default=None, metavar="GLOB",
        help="vault-relative glob to scope out of scanning (repeatable)",
    )
    parser.add_argument("--strict", action="store_true", help="exit 1 when any issue is found")
    args = parser.parse_args(argv)

    root = _resolve_vault(args.vault)
    try:
        report = lint_vault(
            root, as_of=args.as_of, exclude=args.exclude, frontmatter_policy=args.frontmatter_policy
        )
    except (OSError, ValueError) as exc:
        sys.stderr.write(f"wiki-lint: {exc}\n")
        return 2

    if args.format == "markdown":
        sys.stdout.write(render_markdown(report))
    else:
        sys.stdout.write(json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 1 if args.strict and report["summary"]["issues_found"] else 0


if __name__ == "__main__":
    sys.exit(main())
