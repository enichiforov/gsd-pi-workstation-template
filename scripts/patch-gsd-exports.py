#!/usr/bin/env python3
"""Patch npm-installed GSD/Pi package exports for community Pi extensions.

Some community extensions import GSD runtime packages through both legacy
`@earendil-works/*` aliases and current `@gsd/*` names. Recent
`@opengsd/gsd-pi` npm builds ship several of those packages with ESM-oriented
export maps that can break lifecycle extension loading in Node's mixed import
path.

This script is intentionally small, idempotent, and local to the machine. It
only adds missing `default` export entries and the missing `./oauth` subpath
when the referenced files exist.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def npm_root_global() -> Path | None:
    try:
        out = subprocess.check_output(["npm", "root", "-g"], text=True).strip()
    except Exception:
        return None
    return Path(out) if out else None


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def write_json(path: Path, data: dict[str, Any], *, dry_run: bool) -> None:
    if not dry_run:
        backup = path.with_name(f"{path.name}.gsd-pi-workstation.bak")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def add_default_exports(pkg_json: Path, *, dry_run: bool) -> bool:
    data = load_json(pkg_json)
    exports = data.get("exports")
    if not isinstance(exports, dict):
        return False
    changed = False
    for key in (".", "./*"):
        entry = exports.get(key)
        if isinstance(entry, dict) and entry.get("import") and not entry.get("default"):
            entry["default"] = entry["import"]
            changed = True
    if changed:
        write_json(pkg_json, data, dry_run=dry_run)
    return changed


def add_pi_ai_oauth_export(pkg_json: Path, *, dry_run: bool) -> bool:
    data = load_json(pkg_json)
    exports = data.setdefault("exports", {})
    if not isinstance(exports, dict):
        return False
    pkg_dir = pkg_json.parent
    oauth_js = pkg_dir / "dist" / "oauth.js"
    oauth_dts = pkg_dir / "dist" / "oauth.d.ts"
    if not oauth_js.exists():
        return False
    desired = {
        "types": "./dist/oauth.d.ts" if oauth_dts.exists() else "./dist/oauth.js",
        "import": "./dist/oauth.js",
        "default": "./dist/oauth.js",
    }
    if exports.get("./oauth") == desired:
        return False
    exports["./oauth"] = desired
    write_json(pkg_json, data, dry_run=dry_run)
    return True


def candidate_packages(gsd_root: Path) -> list[Path]:
    package_names = {
        "@earendil-works": ("pi-agent-core", "pi-ai", "pi-coding-agent", "pi-tui"),
        "@gsd": ("agent-core", "agent-modes", "pi-agent-core", "pi-ai", "pi-coding-agent", "pi-tui"),
    }
    return [
        gsd_root / "node_modules" / scope / package / "package.json"
        for scope, packages in package_names.items()
        for package in packages
    ]


def installed_gsd_version(gsd_root: Path) -> tuple[int, int, int] | None:
    value = load_json(gsd_root / "package.json").get("version")
    if not isinstance(value, str):
        return None
    numeric = value.split("-", 1)[0].split(".")
    if len(numeric) != 3 or not all(part.isdigit() for part in numeric):
        return None
    return int(numeric[0]), int(numeric[1]), int(numeric[2])


def supports_patch(version: tuple[int, int, int] | None) -> bool:
    return version is not None and (
        (1, 7, 0) <= version < (1, 9, 0) or (1, 11, 0) <= version < (1, 12, 0)
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="return non-zero if a compatibility patch is needed")
    args = parser.parse_args()

    root = npm_root_global()
    if root is None:
        print("WARN could not locate global npm root; skipped GSD export patch", file=sys.stderr)
        return 0

    gsd_root = root / "@opengsd" / "gsd-pi"
    if not gsd_root.exists():
        print(f"WARN @opengsd/gsd-pi not found under {root}; skipped GSD export patch", file=sys.stderr)
        return 0

    packages = [pkg for pkg in candidate_packages(gsd_root) if pkg.exists()]
    changes: list[str] = []
    for pkg in packages:
        if add_default_exports(pkg, dry_run=True):
            changes.append(f"default exports: {pkg}")
        if pkg.parent.name == "pi-ai" and add_pi_ai_oauth_export(pkg, dry_run=True):
            changes.append(f"oauth export: {pkg}")

    if not changes:
        print("GSD/Pi package exports already compatible or no patch needed")
        return 0

    print("GSD/Pi package export compatibility patch is needed:")
    for item in changes:
        print(f"- {item}")
    if args.check:
        return 1

    version = installed_gsd_version(gsd_root)
    if not supports_patch(version):
        rendered = "unknown" if version is None else ".".join(str(part) for part in version)
        print(
            f"REFUSED compatibility patch for unsupported GSD/Pi version {rendered}; "
            "supported ranges are >=1.7.0,<1.9.0 and >=1.11.0,<1.12.0",
            file=sys.stderr,
        )
        return 2

    for pkg in packages:
        add_default_exports(pkg, dry_run=False)
        if pkg.parent.name == "pi-ai":
            add_pi_ai_oauth_export(pkg, dry_run=False)
    print("Patched GSD/Pi package exports")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
