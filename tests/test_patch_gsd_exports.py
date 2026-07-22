from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "patch-gsd-exports.py"


def load_module():
    spec = importlib.util.spec_from_file_location("patch_gsd_exports", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GsdExportPatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.patch = load_module()

    def test_reads_stable_semantic_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "package.json").write_text('{"version":"1.8.1"}', encoding="utf-8")
            self.assertEqual(self.patch.installed_gsd_version(root), (1, 8, 1))

    def test_accepts_prerelease_suffix_when_reading_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "package.json").write_text(
                '{"version":"1.8.0-beta.2"}', encoding="utf-8"
            )
            self.assertEqual(self.patch.installed_gsd_version(root), (1, 8, 0))

    def test_rejects_invalid_version_shape(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "package.json").write_text('{"version":"next"}', encoding="utf-8")
            self.assertIsNone(self.patch.installed_gsd_version(root))

    def test_candidate_packages_cover_runtime_import_surfaces(self) -> None:
        candidates = {
            str(path.relative_to(Path("/tmp/gsd")))
            for path in self.patch.candidate_packages(Path("/tmp/gsd"))
        }
        self.assertIn("node_modules/@earendil-works/pi-agent-core/package.json", candidates)
        self.assertIn("node_modules/@gsd/pi-tui/package.json", candidates)
        self.assertIn("node_modules/@gsd/agent-modes/package.json", candidates)

    def test_patch_is_gated_to_observed_compatible_release_lines(self) -> None:
        self.assertTrue(self.patch.supports_patch((1, 8, 1)))
        self.assertTrue(self.patch.supports_patch((1, 11, 0)))
        self.assertFalse(self.patch.supports_patch((1, 10, 0)))
        self.assertFalse(self.patch.supports_patch((1, 12, 0)))
        self.assertFalse(self.patch.supports_patch(None))

    def test_write_json_creates_recovery_backup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "package.json"
            path.write_text('{"version":"before"}\n', encoding="utf-8")
            self.patch.write_json(path, {"version": "after"}, dry_run=False)
            backup = path.with_name("package.json.gsd-pi-workstation.bak")
            self.assertEqual(backup.read_text(encoding="utf-8"), '{"version":"before"}\n')
            self.assertIn('"after"', path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
