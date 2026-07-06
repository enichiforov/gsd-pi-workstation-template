#!/usr/bin/env python3
"""Patch npm-installed GSD/Pi package exports for community Pi extensions.

Some community extensions import legacy package names such as
`@earendil-works/pi-coding-agent` and `@earendil-works/pi-ai/oauth`.
Recent `@opengsd/gsd-pi` npm builds ship those packages with ESM-oriented
export maps that can break lifecycle extension loading in Node's mixed import
path.

This script is intentionally small, idempotent, and local to the machine. It
only adds missing `default` export entries and the missing `./oauth` subpath
when the referenced files exist.
"""

from __future__ import annotations

import argparse
import json
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
    return [
        gsd_root / "node_modules" / "@earendil-works" / "pi-coding-agent" / "package.json",
        gsd_root / "node_modules" / "@gsd" / "pi-coding-agent" / "package.json",
        gsd_root / "node_modules" / "@earendil-works" / "pi-ai" / "package.json",
        gsd_root / "node_modules" / "@gsd" / "pi-ai" / "package.json",
    ]


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

    dry_run = args.check
    changes: list[str] = []
    for pkg in candidate_packages(gsd_root):
        if not pkg.exists():
            continue
        if add_default_exports(pkg, dry_run=dry_run):
            changes.append(f"default exports: {pkg}")
        if pkg.parent.name == "pi-ai" and add_pi_ai_oauth_export(pkg, dry_run=dry_run):
            changes.append(f"oauth export: {pkg}")

    if changes:
        if args.check:
            print("GSD/Pi package export compatibility patch is needed:")
        else:
            print("Patched GSD/Pi package exports:")
        for item in changes:
            print(f"- {item}")
        return 1 if args.check else 0

    print("GSD/Pi package exports already compatible or no patch needed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
