from __future__ import annotations

import subprocess
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "install.sh"


class InstallerCliTests(unittest.TestCase):
    def run_installer(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(INSTALLER), *arguments],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_minimal_dry_run_has_no_provider_components(self) -> None:
        result = self.run_installer(
            "--profile",
            "minimal",
            "--project-repo",
            "/path/need/not/exist",
            "--dry-run",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("- core", result.stdout)
        self.assertIn("- workspace-config", result.stdout)
        self.assertNotIn("- codex", result.stdout)
        self.assertIn("no changes made", result.stdout)

    def test_legacy_skip_alias_removes_component(self) -> None:
        result = self.run_installer(
            "--profile",
            "developer",
            "--skip-codex",
            "--project-repo",
            "/path/need/not/exist",
            "--dry-run",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("- codex\n", result.stdout)
        self.assertNotIn("- codex-safety-net", result.stdout)

    def test_invalid_profile_fails_before_installation(self) -> None:
        result = self.run_installer("--profile", "unknown", "--dry-run")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Unknown profile", result.stderr)


if __name__ == "__main__":
    unittest.main()
