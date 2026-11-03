"""Hermetic tests for the fork-owned scripts/wiki-lint.py wrapper (exit codes, vault resolution)."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLI = ROOT / "scripts" / "wiki-lint.py"
FIXTURE = ROOT / "tests" / "fixtures" / "lint" / "vault"


def run(*args: str, env: dict[str, str] | None = None, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    merged = {k: v for k, v in os.environ.items() if k != "CLAUDE_OBSIDIAN_VAULT"}
    if env:
        merged.update(env)
    return subprocess.run(
        [sys.executable, str(CLI), *args], capture_output=True, text=True, env=merged, cwd=cwd, check=False
    )


class WikiLintCliTests(unittest.TestCase):
    def test_findings_without_strict_exit_zero(self) -> None:
        completed = run("--vault", str(FIXTURE), "--format", "json")
        self.assertEqual(0, completed.returncode, completed.stderr)
        report = json.loads(completed.stdout)
        self.assertGreater(report["summary"]["issues_found"], 0)

    def test_strict_exits_one_on_findings(self) -> None:
        completed = run("--vault", str(FIXTURE), "--strict")
        self.assertEqual(1, completed.returncode, completed.stderr)
        self.assertIn("# Wiki Lint Report", completed.stdout)

    def test_markdown_is_default_format(self) -> None:
        completed = run("--vault", str(FIXTURE))
        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertTrue(completed.stdout.startswith("# Wiki Lint Report"))

    def test_vault_without_wiki_dir_exits_two(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            completed = run("--vault", tmp)
        self.assertEqual(2, completed.returncode)
        self.assertIn("has no wiki/ directory", completed.stderr)
        self.assertEqual("", completed.stdout)

    def test_env_var_resolves_vault(self) -> None:
        completed = run("--format", "json", env={"CLAUDE_OBSIDIAN_VAULT": str(FIXTURE)})
        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["summary"]["page_scope"] if "page_scope" in json.loads(completed.stdout)["summary"] else "wiki", "wiki")

    def test_cwd_resolves_vault(self) -> None:
        completed = run("--format", "json", cwd=FIXTURE)
        self.assertEqual(0, completed.returncode, completed.stderr)
        json.loads(completed.stdout)

    def test_runs_are_byte_identical(self) -> None:
        first = run("--vault", str(FIXTURE), "--format", "json").stdout
        second = run("--vault", str(FIXTURE), "--format", "json").stdout
        self.assertEqual(first, second)

    def test_json_keeps_non_ascii(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            vault = Path(tmp)
            (vault / "wiki").mkdir()
            (vault / "wiki" / "index.md").write_text(
                "---\ntype: meta\nstatus: evergreen\ncreated: 2026-01-01\nupdated: 2026-01-01\ntags: []\n---\n\n[[Café]]\n",
                encoding="utf-8",
            )
            completed = run("--vault", str(vault), "--format", "json")
        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertIn("Café", completed.stdout)
        self.assertNotIn("\\u00e9", completed.stdout)

    def test_engine_oserror_exits_two_not_one(self) -> None:
        """An OSError from the engine must map to exit 2, never collide with --strict's 1."""
        import importlib.util
        from unittest import mock

        spec = importlib.util.spec_from_file_location("wiki_lint_cli", CLI)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)
        with mock.patch.object(module, "lint_vault", side_effect=PermissionError("denied")):
            with mock.patch("sys.stderr") as stderr:
                rc = module.main(["--vault", str(FIXTURE), "--strict"])
        self.assertEqual(2, rc)
        written = "".join(call.args[0] for call in stderr.write.call_args_list)
        self.assertIn("wiki-lint: denied", written)

if __name__ == "__main__":
    unittest.main()
