from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "scripts" / "python-skills.py"
MANIFEST_PATH = ROOT / "manifests" / "python-skills.json"
SOURCE_ROOT = ROOT / "templates" / "agents-skills"
EXPECTED_SKILLS = (
    "python-architecture-patterns",
    "python-async-concurrency-deep-dive",
    "python-authentication-and-authorization",
    "python-code-quality-fundamentals",
    "python-database-patterns",
    "python-debugging-and-observability",
    "python-environment-and-config",
    "python-performance-optimization",
    "python-testing-and-mocks",
    "python-web-service-runtime",
)


def load_python_skills_module():
    spec = importlib.util.spec_from_file_location(
        "workstation_python_skills", MODULE_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PythonSkillsBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = load_python_skills_module()
        cls.manifest = cls.bundle.load_manifest(MANIFEST_PATH)

    def test_manifest_declares_the_complete_bundle(self) -> None:
        self.assertEqual(
            tuple(skill.name for skill in self.manifest.skills),
            EXPECTED_SKILLS,
        )

    def test_source_tree_matches_manifest_and_skill_contracts(self) -> None:
        self.bundle.validate_source(self.manifest, SOURCE_ROOT)
        self.bundle.validate_skill_documents(self.manifest, SOURCE_ROOT)

    def test_source_tree_rejects_unmanifested_root_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "skills"
            shutil.copytree(SOURCE_ROOT, source)
            (source / "stray.txt").write_text("not in manifest\n", encoding="utf-8")

            with self.assertRaisesRegex(self.bundle.BundleError, "do not match"):
                self.bundle.validate_source(self.manifest, source)

    def test_shell_entrypoints_delegate_complete_bundle_operations(self) -> None:
        installer = (ROOT / "scripts" / "install.sh").read_text(encoding="utf-8")
        verifier = (ROOT / "scripts" / "verify.sh").read_text(encoding="utf-8")
        docker_smoke = (ROOT / "scripts" / "docker-smoke.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('python-skills.py"', installer)
        self.assertIn('python-skills.py"', verifier)
        self.assertIn('"$ROOT/manifests/python-skills.json"', installer)
        self.assertIn('"$ROOT/manifests/python-skills.json"', verifier)
        self.assertNotIn("templates/agents-skills/*/SKILL.md", installer)
        self.assertNotIn("templates/agents-skills/*/SKILL.md", verifier)
        self.assertEqual(docker_smoke.count("--include python-skills"), 2)

    def test_install_and_verify_complete_skill_trees(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            backup = root / "backups" / "run-1"

            outcomes = self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=False,
                backup_root=backup,
            )

            self.assertEqual({item.status for item in outcomes}, {"installed"})
            self.bundle.verify_bundle(self.manifest, SOURCE_ROOT, destination)
            self.assertTrue(
                (
                    destination
                    / "python-authentication-and-authorization"
                    / "references"
                    / "jwt-validation.md"
                ).is_file()
            )
            self.assertTrue(
                (
                    destination
                    / "python-web-service-runtime"
                    / "agents"
                    / "openai.yaml"
                ).is_file()
            )

    def test_no_overwrite_skips_a_different_skill_as_one_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            backup = root / "backups" / "run-1"
            self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=False,
                backup_root=backup,
            )

            skill_root = destination / "python-architecture-patterns"
            skill_md = skill_root / "SKILL.md"
            missing_reference = skill_root / "references" / "application-boundaries.md"
            skill_md.write_text(
                skill_md.read_text(encoding="utf-8") + "\nlocal change\n",
                encoding="utf-8",
            )
            missing_reference.unlink()

            outcomes = self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=False,
                backup_root=backup,
            )
            by_name = {item.name: item.status for item in outcomes}

            self.assertEqual(by_name["python-architecture-patterns"], "skipped")
            self.assertIn("local change", skill_md.read_text(encoding="utf-8"))
            self.assertFalse(missing_reference.exists())

    def test_overwrite_backs_up_and_replaces_the_complete_skill(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            backup = root / "backups" / "run-2"
            self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=False,
                backup_root=backup,
            )

            skill_root = destination / "python-architecture-patterns"
            skill_md = skill_root / "SKILL.md"
            skill_md.write_text("local replacement\n", encoding="utf-8")
            (skill_root / "local-note.md").write_text(
                "keep in backup\n", encoding="utf-8"
            )

            outcomes = self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=True,
                backup_root=backup,
            )
            by_name = {item.name: item.status for item in outcomes}
            backed_up_skill = (
                backup
                / destination.resolve().relative_to(destination.anchor)
                / "python-architecture-patterns"
            )

            self.assertEqual(by_name["python-architecture-patterns"], "replaced")
            self.assertEqual(
                (backed_up_skill / "SKILL.md").read_text(encoding="utf-8"),
                "local replacement\n",
            )
            self.assertTrue((backed_up_skill / "local-note.md").is_file())
            self.assertFalse((skill_root / "local-note.md").exists())
            self.bundle.verify_bundle(self.manifest, SOURCE_ROOT, destination)

    def test_overwrite_backs_up_a_conflicting_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            destination.mkdir(parents=True)
            conflict = destination / "python-architecture-patterns"
            conflict.write_text("local file\n", encoding="utf-8")
            backup = root / "backups" / "run-file"

            outcomes = self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=True,
                backup_root=backup,
            )
            absolute_conflict = conflict.parent.resolve() / conflict.name
            backed_up = backup / absolute_conflict.relative_to(absolute_conflict.anchor)

            self.assertEqual(outcomes[0].status, "replaced")
            self.assertEqual(backed_up.read_text(encoding="utf-8"), "local file\n")
            self.assertTrue((conflict / "SKILL.md").is_file())
            self.bundle.verify_bundle(self.manifest, SOURCE_ROOT, destination)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks are unavailable")
    def test_overwrite_does_not_follow_a_conflicting_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            destination.mkdir(parents=True)
            external = root / "external-skill"
            external.mkdir()
            (external / "sentinel.txt").write_text("external\n", encoding="utf-8")
            conflict = destination / "python-architecture-patterns"
            conflict.symlink_to(external, target_is_directory=True)
            backup = root / "backups" / "run-symlink"

            outcomes = self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=True,
                backup_root=backup,
            )
            absolute_conflict = conflict.parent.resolve() / conflict.name
            backed_up = backup / absolute_conflict.relative_to(absolute_conflict.anchor)

            self.assertEqual(outcomes[0].status, "replaced")
            self.assertTrue(backed_up.is_symlink())
            self.assertEqual(os.readlink(backed_up), str(external))
            self.assertEqual(
                (external / "sentinel.txt").read_text(encoding="utf-8"),
                "external\n",
            )
            self.assertFalse(conflict.is_symlink())
            self.bundle.verify_bundle(self.manifest, SOURCE_ROOT, destination)

    def test_verify_rejects_a_partial_or_modified_install(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = root / "home" / ".agents" / "skills"
            self.bundle.install_bundle(
                self.manifest,
                SOURCE_ROOT,
                destination,
                overwrite=False,
                backup_root=root / "backups",
            )
            (
                destination
                / "python-testing-and-mocks"
                / "references"
                / "async-tests.md"
            ).unlink()

            with self.assertRaisesRegex(self.bundle.BundleError, "does not match"):
                self.bundle.verify_bundle(self.manifest, SOURCE_ROOT, destination)


if __name__ == "__main__":
    unittest.main()
