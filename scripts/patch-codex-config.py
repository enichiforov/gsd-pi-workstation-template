#!/usr/bin/env python3
"""Patch ~/.codex/config.toml for GSD/Pi workstation defaults without touching auth."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT_KEYS = {
    "approval_policy": '"never"',
    "sandbox_mode": '"danger-full-access"',
    "sandbox": '"danger-full-access"',
    "model": '"gpt-5.6-sol"',
    "model_reasoning_effort": '"xhigh"',
    "service_tier": '"default"',
}


def split_tables(lines: list[str]) -> tuple[list[str], dict[str, list[str]], list[str]]:
    root: list[str] = []
    tables: dict[str, list[str]] = {}
    order: list[str] = []
    current: str | None = None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            current = stripped
            if current not in tables:
                tables[current] = [line]
                order.append(current)
            else:
                tables[current].append(line)
            continue
        if current is None:
            root.append(line)
        else:
            tables[current].append(line)
    return root, tables, order


def set_kv(lines: list[str], key: str, value: str) -> list[str]:
    rendered = f"{key} = {value}\n"
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(f"{key} ") or stripped.startswith(f"{key}="):
            lines[i] = rendered
            return lines
    if lines and lines[-1].strip():
        lines.append("\n")
    lines.append(rendered)
    return lines


def ensure_table(tables: dict[str, list[str]], order: list[str], name: str) -> list[str]:
    if name not in tables:
        tables[name] = [f"{name}\n"]
        order.append(name)
    return tables[name]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--project-repo", default=str(Path.home() / "YourProject"))
    args = parser.parse_args()

    args.path.parent.mkdir(parents=True, exist_ok=True)
    original = args.path.read_text() if args.path.exists() else ""
    lines: list[str] = [str(line) for line in original.splitlines(keepends=True)]
    root, tables, order = split_tables(lines)

    if not root or not root[0].startswith("#"):
        root.insert(0, "# GSD/Pi workstation Codex config managed by gsd-pi-workstation-template.\n")

    for key, value in ROOT_KEYS.items():
        root = set_kv(root, key, value)

    features = ensure_table(tables, order, "[features]")
    tables["[features]"] = set_kv(features, "plugin_hooks", "true")

    project_table = f"[projects.{json.dumps(str(args.project_repo))}]"
    project = ensure_table(tables, order, project_table)
    tables[project_table] = set_kv(project, "trust_level", '"trusted"')

    output = root
    if output and output[-1].strip():
        output.append("\n")
    for name in order:
        block = tables[name]
        if output and output[-1].strip():
            output.append("\n")
        output.extend(block)

    args.path.write_text("".join(output))
    print(f"patched {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
