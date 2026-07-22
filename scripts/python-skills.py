#!/usr/bin/env python3
"""Validate, install, and verify the vendored Python skill bundle."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
from typing import Any, NamedTuple, Sequence
from urllib.parse import unquote
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "manifests" / "python-skills.json"
DEFAULT_SOURCE = ROOT / "templates" / "agents-skills"
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
PYTHON_FENCE_RE = re.compile(
    re.escape(chr(96) * 3) + r"python[ \t]*\n(.*?)" + re.escape(chr(96) * 3),
    flags=re.DOTALL | re.IGNORECASE,
)
FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", flags=re.DOTALL)
OPENAI_FIELD_RE = re.compile(
    r"^[ \t]{2}(display_name|short_description|default_prompt):[ \t]*(.+)$",
    flags=re.MULTILINE,
)


class BundleError(RuntimeError):
    """Raised when a source or installed skill bundle violates its contract."""


class SkillSpec(NamedTuple):
    """One skill and its expected relative-file hashes."""

    name: str
    files: tuple[tuple[str, str], ...]


class BundleManifest(NamedTuple):
    """Validated portable-skill manifest."""

    bundle_version: str
    skills: tuple[SkillSpec, ...]


class InstallOutcome(NamedTuple):
    """Result of installing one skill directory."""

    name: str
    status: str
    destination: Path


def _expect_mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BundleError(f"{label} must be an object")
    return value


def _validate_relative_path(value: str, label: str) -> None:
    path = PurePosixPath(value)
    if (
        not value
        or path.is_absolute()
        or ".." in path.parts
        or path.as_posix() != value
    ):
        raise BundleError(f"{label} must be a normalized relative POSIX path")


def load_manifest(path: Path = DEFAULT_MANIFEST) -> BundleManifest:
    """Load and validate the skill bundle manifest."""
    try:
        raw = _expect_mapping(json.loads(path.read_text(encoding="utf-8")), "manifest")
    except (OSError, json.JSONDecodeError) as error:
        raise BundleError(f"Unable to load Python skills manifest: {error}") from error

    if raw.get("schema_version") != 1:
        raise BundleError("Unsupported Python skills manifest schema_version")
    bundle_version = raw.get("bundle_version")
    if not isinstance(bundle_version, str) or not bundle_version:
        raise BundleError("bundle_version must be a non-empty string")

    raw_skills = raw.get("skills")
    if not isinstance(raw_skills, list) or not raw_skills:
        raise BundleError("skills must be a non-empty array")

    skills: list[SkillSpec] = []
    for index, raw_skill in enumerate(raw_skills):
        data = _expect_mapping(raw_skill, f"skills[{index}]")
        name = data.get("name")
        if not isinstance(name, str) or not SKILL_NAME_RE.fullmatch(name):
            raise BundleError(f"skills[{index}].name is invalid")
        raw_files = _expect_mapping(data.get("files"), f"skills[{index}].files")
        files: list[tuple[str, str]] = []
        for relative, digest in sorted(raw_files.items()):
            if not isinstance(relative, str):
                raise BundleError(f"skills[{index}].files keys must be strings")
            _validate_relative_path(relative, f"skills[{index}].files[{relative!r}]")
            if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise BundleError(
                    f"skills[{index}].files[{relative!r}] must be a SHA-256 hex digest"
                )
            files.append((relative, digest))
        if not files:
            raise BundleError(f"skills[{index}].files must not be empty")
        skills.append(SkillSpec(name=name, files=tuple(files)))

    names = [skill.name for skill in skills]
    if names != sorted(names) or len(names) != len(set(names)):
        raise BundleError("skills must be unique and sorted by name")
    return BundleManifest(bundle_version=bundle_version, skills=tuple(skills))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tree_files(root: Path) -> dict[str, Path]:
    files: dict[str, Path] = {}
    if not root.is_dir():
        return files
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise BundleError(f"Skill bundles must not contain symlinks: {path}")
        if path.is_file():
            relative = path.relative_to(root).as_posix()
            files[relative] = path
    return files


def validate_source(manifest: BundleManifest, source_root: Path) -> None:
    """Require the source tree to match every declared file and hash exactly."""
    if not source_root.is_dir():
        raise BundleError(f"Python skills source directory is missing: {source_root}")

    expected_names = {skill.name for skill in manifest.skills}
    entries = tuple(source_root.iterdir())
    actual_names = {path.name for path in entries}
    invalid_entries = sorted(
        path.name for path in entries if path.is_symlink() or not path.is_dir()
    )
    if actual_names != expected_names or invalid_entries:
        raise BundleError(
            "Python skills source directories do not match the manifest: "
            f"expected={sorted(expected_names)} actual={sorted(actual_names)} "
            f"invalid_entries={invalid_entries}"
        )

    errors: list[str] = []
    for skill in manifest.skills:
        root = source_root / skill.name
        actual_files = _tree_files(root)
        expected_files = dict(skill.files)
        if set(actual_files) != set(expected_files):
            errors.append(
                f"{skill.name}: expected files {sorted(expected_files)}, "
                f"found {sorted(actual_files)}"
            )
            continue
        for relative, expected_hash in skill.files:
            actual_hash = _sha256(actual_files[relative])
            if actual_hash != expected_hash:
                errors.append(
                    f"{skill.name}/{relative}: SHA-256 {actual_hash}, "
                    f"expected {expected_hash}"
                )
    if errors:
        raise BundleError(
            "Python skills source does not match manifest:\n- " + "\n- ".join(errors)
        )


def _parse_frontmatter(path: Path, text: str) -> dict[str, str]:
    match = FRONTMATTER_RE.match(text)
    if match is None:
        raise BundleError(f"{path}: missing YAML frontmatter")
    values: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            raise BundleError(f"{path}: invalid frontmatter line {line!r}")
        key, raw_value = line.split(":", 1)
        key = key.strip()
        raw_value = raw_value.strip()
        try:
            value = json.loads(raw_value) if raw_value.startswith('"') else raw_value
        except json.JSONDecodeError as error:
            raise BundleError(f"{path}: invalid quoted frontmatter value") from error
        if not isinstance(value, str):
            raise BundleError(f"{path}: frontmatter {key} must be a string")
        values[key] = value
    if set(values) != {"name", "description"}:
        raise BundleError(f"{path}: frontmatter must contain only name and description")
    return values


def _validate_markdown_links(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    for raw_target in MARKDOWN_LINK_RE.findall(text):
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(
            ("#", "/", "http://", "https://", "mailto:")
        ):
            continue
        relative = unquote(target.split("#", maxsplit=1)[0])
        if relative and not (path.parent / relative).resolve().exists():
            errors.append(f"{path}: missing linked file {target!r}")
    return errors


def _validate_python_fences(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    for index, snippet in enumerate(PYTHON_FENCE_RE.findall(text), start=1):
        try:
            compile(
                snippet,
                f"{path}::python-fence-{index}",
                "exec",
                flags=ast.PyCF_ALLOW_TOP_LEVEL_AWAIT,
            )
        except SyntaxError as error:
            errors.append(
                f"{path}: Python fence {index} does not compile: "
                f"{error.msg} at line {error.lineno}"
            )
    return errors


def validate_skill_documents(manifest: BundleManifest, source_root: Path) -> None:
    """Validate skill frontmatter, metadata, links, portability, and Python examples."""
    validate_source(manifest, source_root)
    errors: list[str] = []
    for skill in manifest.skills:
        skill_root = source_root / skill.name
        skill_path = skill_root / "SKILL.md"
        skill_text = skill_path.read_text(encoding="utf-8")
        try:
            frontmatter = _parse_frontmatter(skill_path, skill_text)
        except BundleError as error:
            errors.append(str(error))
            continue
        if frontmatter["name"] != skill.name:
            errors.append(
                f"{skill_path}: name {frontmatter['name']!r} does not match {skill.name!r}"
            )
        if not frontmatter["description"].strip():
            errors.append(f"{skill_path}: description must not be empty")
        if len(skill_text.splitlines()) >= 500:
            errors.append(f"{skill_path}: SKILL.md must stay below 500 lines")

        openai_path = skill_root / "agents" / "openai.yaml"
        if not openai_path.is_file():
            errors.append(f"{openai_path}: missing agents/openai.yaml")
        else:
            openai_text = openai_path.read_text(encoding="utf-8")
            fields = dict(OPENAI_FIELD_RE.findall(openai_text))
            missing = {
                "display_name",
                "short_description",
                "default_prompt",
            } - set(fields)
            if missing:
                errors.append(
                    f"{openai_path}: missing interface fields {sorted(missing)}"
                )
            elif "$" + skill.name not in fields["default_prompt"]:
                errors.append(
                    f"{openai_path}: default_prompt must mention $" + skill.name
                )

        for markdown_path in sorted(skill_root.rglob("*.md")):
            text = markdown_path.read_text(encoding="utf-8")
            if "/Users/" in text:
                errors.append(f"{markdown_path}: contains a private absolute home path")
            errors.extend(_validate_markdown_links(markdown_path, text))
            errors.extend(_validate_python_fences(markdown_path, text))
    if errors:
        raise BundleError(
            "Python skill document validation failed:\n- " + "\n- ".join(errors)
        )


def _trees_match(source: Path, destination: Path) -> bool:
    if source.is_symlink() or destination.is_symlink():
        return False
    if not source.is_dir() or not destination.is_dir():
        return False
    source_files = _tree_files(source)
    destination_files = _tree_files(destination)
    if set(source_files) != set(destination_files):
        return False
    return all(
        _sha256(source_files[relative]) == _sha256(destination_files[relative])
        for relative in source_files
    )


def _path_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def _remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def _copy_tree_atomic(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.parent / f".{destination.name}.tmp-{uuid4().hex}"
    try:
        shutil.copytree(source, temporary)
        os.replace(temporary, destination)
    finally:
        if _path_exists(temporary):
            _remove_path(temporary)


def _backup_tree(source: Path, backup_root: Path) -> Path:
    absolute = source.parent.resolve() / source.name
    relative = absolute.relative_to(absolute.anchor)
    destination = backup_root / relative
    if _path_exists(destination):
        raise BundleError(f"Backup destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        os.symlink(os.readlink(source), destination)
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination, follow_symlinks=False)
    return destination


def _replace_tree_atomic(source: Path, destination: Path) -> None:
    temporary = destination.parent / f".{destination.name}.tmp-{uuid4().hex}"
    previous = destination.parent / f".{destination.name}.old-{uuid4().hex}"
    shutil.copytree(source, temporary)
    os.replace(destination, previous)
    try:
        os.replace(temporary, destination)
    except BaseException:
        os.replace(previous, destination)
        raise
    else:
        _remove_path(previous)
    finally:
        if _path_exists(temporary):
            _remove_path(temporary)


def install_bundle(
    manifest: BundleManifest,
    source_root: Path,
    destination_root: Path,
    *,
    overwrite: bool,
    backup_root: Path,
) -> tuple[InstallOutcome, ...]:
    """Install each skill as one coherent tree, backing up replacements."""
    validate_skill_documents(manifest, source_root)
    destination_root.mkdir(parents=True, exist_ok=True)
    outcomes: list[InstallOutcome] = []
    for skill in manifest.skills:
        source = source_root / skill.name
        destination = destination_root / skill.name
        if not _path_exists(destination):
            _copy_tree_atomic(source, destination)
            status = "installed"
        elif _trees_match(source, destination):
            status = "unchanged"
        elif not overwrite:
            status = "skipped"
        else:
            _backup_tree(destination, backup_root)
            _replace_tree_atomic(source, destination)
            status = "replaced"
        outcomes.append(InstallOutcome(skill.name, status, destination))
    return tuple(outcomes)


def verify_bundle(
    manifest: BundleManifest,
    source_root: Path,
    destination_root: Path,
) -> None:
    """Require installed skill trees to match the validated vendored source."""
    validate_source(manifest, source_root)
    errors: list[str] = []
    for skill in manifest.skills:
        source = source_root / skill.name
        destination = destination_root / skill.name
        if (
            destination.is_symlink()
            or not destination.is_dir()
            or not _trees_match(source, destination)
        ):
            errors.append(
                f"{skill.name}: {destination} does not match the vendored source"
            )
    if errors:
        raise BundleError(
            "Installed Python skills bundle does not match source:\n- "
            + "\n- ".join(errors)
        )


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("validate", help="Validate source hashes and skill documents")

    install = subparsers.add_parser("install", help="Install the complete skill bundle")
    install.add_argument("--destination", type=Path, required=True)
    install.add_argument("--backup-root", type=Path, required=True)
    install.add_argument("--overwrite", action="store_true")

    verify = subparsers.add_parser("verify", help="Verify an installed skill bundle")
    verify.add_argument("--destination", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Run the selected bundle operation."""
    args = build_parser().parse_args(argv)
    try:
        manifest = load_manifest(args.manifest)
        if args.command == "validate":
            validate_skill_documents(manifest, args.source)
            print(
                f"validated Python skills bundle {manifest.bundle_version}: "
                f"{len(manifest.skills)} skills"
            )
        elif args.command == "install":
            outcomes = install_bundle(
                manifest,
                args.source,
                args.destination,
                overwrite=args.overwrite,
                backup_root=args.backup_root,
            )
            for outcome in outcomes:
                if outcome.status == "skipped":
                    print(
                        "exists/different, skipped complete skill without --overwrite: "
                        f"{outcome.destination}",
                        file=sys.stderr,
                    )
                else:
                    print(f"{outcome.status}: {outcome.destination}")
        else:
            verify_bundle(manifest, args.source, args.destination)
            print(
                f"verified Python skills bundle {manifest.bundle_version}: "
                f"{len(manifest.skills)} skills"
            )
        return 0
    except (BundleError, OSError) as error:
        print(f"python-skills error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
