#!/usr/bin/env python3
"""Resolve declarative workstation profiles into ordered components."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, NamedTuple, Sequence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "manifests" / "components.json"


class Component(NamedTuple):
    name: str
    description: str
    depends_on: tuple[str, ...]
    internal: bool


class Profile(NamedTuple):
    name: str
    description: str
    components: tuple[str, ...]


class Manifest(NamedTuple):
    default_profile: str
    profiles: dict[str, Profile]
    components: dict[str, Component]
    gsd_packages: tuple[dict[str, str], ...]


def _expect_mapping(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    return value


def _expect_strings(value: Any, label: str) -> tuple[str, ...]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{label} must be an array of strings")
    return tuple(value)


def load_manifest(path: Path = DEFAULT_MANIFEST) -> Manifest:
    """Load and validate the public component manifest."""
    raw = _expect_mapping(json.loads(path.read_text(encoding="utf-8")), "manifest")
    if raw.get("schema_version") != 1:
        raise ValueError("Unsupported components manifest schema_version")

    raw_components = _expect_mapping(raw.get("components"), "components")
    components: dict[str, Component] = {}
    for name, value in raw_components.items():
        data = _expect_mapping(value, f"component {name}")
        components[name] = Component(
            name=name,
            description=str(data.get("description", "")),
            depends_on=_expect_strings(data.get("depends_on", []), f"component {name}.depends_on"),
            internal=bool(data.get("internal", False)),
        )

    raw_profiles = _expect_mapping(raw.get("profiles"), "profiles")
    profiles: dict[str, Profile] = {}
    for name, value in raw_profiles.items():
        data = _expect_mapping(value, f"profile {name}")
        profiles[name] = Profile(
            name=name,
            description=str(data.get("description", "")),
            components=_expect_strings(data.get("components"), f"profile {name}.components"),
        )

    default_profile = raw.get("default_profile")
    if not isinstance(default_profile, str) or default_profile not in profiles:
        raise ValueError("default_profile must name a declared profile")

    raw_packages = raw.get("gsd_packages", [])
    if not isinstance(raw_packages, list):
        raise ValueError("gsd_packages must be an array")
    packages: list[dict[str, str]] = []
    for index, value in enumerate(raw_packages):
        data = _expect_mapping(value, f"gsd_packages[{index}]")
        component = data.get("component")
        source = data.get("source")
        if not isinstance(component, str) or component not in components:
            raise ValueError(f"gsd_packages[{index}].component is unknown")
        if not isinstance(source, str) or not source:
            raise ValueError(f"gsd_packages[{index}].source must be a non-empty string")
        packages.append({"component": component, "source": source})

    manifest = Manifest(default_profile, profiles, components, tuple(packages))
    _validate_references(manifest)
    return manifest


def _validate_references(manifest: Manifest) -> None:
    for component in manifest.components.values():
        for dependency in component.depends_on:
            if dependency not in manifest.components:
                raise ValueError(f"Component {component.name} depends on unknown component {dependency}")
    for profile in manifest.profiles.values():
        for component in profile.components:
            if component not in manifest.components:
                raise ValueError(f"Profile {profile.name} contains unknown component {component}")


def resolve_components(
    manifest: Manifest,
    profile_name: str | None,
    include: Sequence[str] = (),
    exclude: Sequence[str] = (),
) -> tuple[str, ...]:
    """Resolve a profile and overrides into dependency-ordered component names."""
    selected_profile = profile_name or manifest.default_profile
    if selected_profile not in manifest.profiles:
        raise ValueError(f"Unknown profile: {selected_profile}")

    requested = list(manifest.profiles[selected_profile].components)
    requested.extend(include)
    excluded = set(exclude)
    for name in (*requested, *excluded):
        if name not in manifest.components:
            raise ValueError(f"Unknown component: {name}")

    ordered: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str, dependant: str | None = None) -> None:
        if name in excluded:
            if dependant is not None:
                raise ValueError(f"Component {dependant} requires excluded component {name}")
            return
        if name in visited:
            return
        if name in visiting:
            raise ValueError(f"Component dependency cycle detected at {name}")
        visiting.add(name)
        for dependency in manifest.components[name].depends_on:
            visit(dependency, dependant=name)
        visiting.remove(name)
        visited.add(name)
        ordered.append(name)

    for component in requested:
        visit(component)
    return tuple(ordered)


def package_sources(manifest: Manifest, selected: Sequence[str]) -> tuple[str, ...]:
    selected_set = set(selected)
    return tuple(
        package["source"]
        for package in manifest.gsd_packages
        if package["component"] in selected_set
    )


def _csv(values: Sequence[str]) -> tuple[str, ...]:
    return tuple(item for value in values for item in value.split(",") if item)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list", help="List available profiles and public components")

    resolve = subparsers.add_parser("resolve", help="Resolve a profile to ordered components")
    resolve.add_argument("--profile")
    resolve.add_argument("--include", action="append", default=[])
    resolve.add_argument("--exclude", action="append", default=[])
    resolve.add_argument("--packages", action="store_true", help="Print selected pinned GSD package sources")
    resolve.add_argument("--json", action="store_true", help="Print a JSON array instead of one item per line")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        manifest = load_manifest(args.manifest)
        if args.command == "list":
            print(f"Default profile: {manifest.default_profile}\n")
            print("Profiles:")
            for profile in manifest.profiles.values():
                print(f"  {profile.name:<10} {profile.description}")
            print("\nComponents:")
            for component in manifest.components.values():
                if not component.internal:
                    print(f"  {component.name:<20} {component.description}")
            return 0

        selected = resolve_components(
            manifest,
            profile_name=args.profile,
            include=_csv(args.include),
            exclude=_csv(args.exclude),
        )
        values = package_sources(manifest, selected) if args.packages else selected
        if args.json:
            print(json.dumps(values))
        else:
            print("\n".join(values))
        return 0
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"profile error: {error}", file=__import__("sys").stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
