from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class ManifestConsistencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.components = json.loads(
            (ROOT / "manifests" / "components.json").read_text(encoding="utf-8")
        )
        cls.inventory = json.loads(
            (ROOT / "manifests" / "pinned-inventory.json").read_text(encoding="utf-8")
        )
        cls.marketplace = json.loads(
            (ROOT / "manifests" / "marketplace-plugins.json").read_text(encoding="utf-8")
        )

    def test_npm_package_sources_match_pinned_inventory(self) -> None:
        pins = self.inventory["pinned_dependencies"]
        for package in self.components["gsd_packages"]:
            source = package["source"]
            if not source.startswith("npm:"):
                continue
            spec = source.removeprefix("npm:")
            name, version = spec.rsplit("@", 1)
            self.assertEqual(version, pins[name], name)

    def test_git_package_source_matches_pinned_inventory(self) -> None:
        source = next(
            package["source"]
            for package in self.components["gsd_packages"]
            if package["source"].startswith("git:")
        )
        repository_and_ref = source.removeprefix("git:github.com/")
        repository, ref = repository_and_ref.rsplit("@", 1)
        pin = self.inventory["git_sources"]["pi-multi-pass"]
        self.assertEqual(repository, pin["repository"])
        self.assertEqual(ref, pin["ref"])

    def test_coding_marketplace_ref_matches_inventory(self) -> None:
        pin = self.inventory["git_sources"]["coding-workflows"]
        self.assertEqual(self.marketplace["marketplace"]["source"], pin["repository"])
        self.assertEqual(self.marketplace["marketplace"]["ref"], pin["ref"])

    def test_every_profile_component_exists(self) -> None:
        known = set(self.components["components"])
        for profile in self.components["profiles"].values():
            self.assertLessEqual(set(profile["components"]), known)


if __name__ == "__main__":
    unittest.main()
