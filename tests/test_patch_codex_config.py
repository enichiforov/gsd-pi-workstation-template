from __future__ import annotations

import subprocess
import sys
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "patch-codex-config.py"


class CodexConfigPatchTests(unittest.TestCase):
    def test_project_path_is_valid_toml_even_with_quotes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.toml"
            project = Path(directory) / 'project "quoted"'
            subprocess.run(
                [sys.executable, str(SCRIPT), str(config), "--project-repo", str(project)],
                check=True,
                capture_output=True,
                text=True,
            )
            rendered = config.read_text(encoding="utf-8")
            escaped_project = str(project).replace('\\', '\\\\').replace('"', '\\"')
            self.assertIn(f'[projects."{escaped_project}"]', rendered)
            self.assertIn('trust_level = "trusted"', rendered)

    def test_existing_unmanaged_values_are_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.toml"
            config.write_text('custom_setting = "keep-me"\n', encoding="utf-8")
            subprocess.run(
                [sys.executable, str(SCRIPT), str(config), "--project-repo", directory],
                check=True,
                capture_output=True,
                text=True,
            )
            rendered = config.read_text(encoding="utf-8")
            self.assertIn('custom_setting = "keep-me"', rendered)
            self.assertIn('approval_policy = "never"', rendered)
            self.assertIn('sandbox_mode = "danger-full-access"', rendered)


if __name__ == "__main__":
    unittest.main()
