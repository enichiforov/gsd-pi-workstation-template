from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "profile.py"
MANIFEST_PATH = ROOT / "manifests" / "components.json"


def load_profile_module():
    spec = importlib.util.spec_from_file_location("workstation_profile", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ProfileResolutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.profile = load_profile_module()
        cls.manifest = cls.profile.load_manifest(MANIFEST_PATH)

    def test_full_is_the_declared_default_profile(self) -> None:
        self.assertEqual(self.manifest.default_profile, "full")
        selected = self.profile.resolve_components(self.manifest, profile_name=None)
        self.assertIn("codex", selected)
        self.assertIn("codex-safety-net", selected)
        self.assertIn("graphify", selected)

    def test_minimal_profile_contains_only_portable_core(self) -> None:
        selected = self.profile.resolve_components(self.manifest, profile_name="minimal")
        self.assertEqual(selected, ("core", "workspace-config"))

    def test_dependencies_are_added_before_dependants(self) -> None:
        selected = self.profile.resolve_components(
            self.manifest,
            profile_name="minimal",
            include=("codex",),
        )
        self.assertLess(selected.index("codex-safety-net"), selected.index("codex"))
        self.assertLess(selected.index("core"), selected.index("codex-safety-net"))

    def test_excluding_a_required_dependency_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "requires excluded component"):
            self.profile.resolve_components(
                self.manifest,
                profile_name="full",
                exclude=("codex-safety-net",),
            )

    def test_unknown_component_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "Unknown component"):
            self.profile.resolve_components(
                self.manifest,
                profile_name="minimal",
                include=("does-not-exist",),
            )

    def test_manifest_is_publicly_readable_json(self) -> None:
        raw = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(raw["schema_version"], 1)
        self.assertIn("profiles", raw)
        self.assertIn("components", raw)


if __name__ == "__main__":
    unittest.main()
