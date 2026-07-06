#!/usr/bin/env python3
"""Small public-readiness scanner for this template repo."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "github_token": re.compile(r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"),
    "openai_key": re.compile(r"sk-[A-Za-z0-9]{16,}|sk-proj-[A-Za-z0-9_-]+"),
    "private_key": re.compile(r"BEGIN (?:RSA|OPENSSH|PRIVATE) KEY"),
    "aws_key": re.compile(r"AKIA[0-9A-Z]{16}"),
    "absolute_private_home": re.compile(r"/Users/[A-Za-z0-9._-]+"),
    "op_ref": re.compile(r"op://"),
}

SKIP_PARTS = {".git", "node_modules", "__pycache__"}


def main() -> int:
    findings: list[tuple[str, str, int]] = []
    scanned = 0
    self_path = Path(__file__).resolve()
    for path in ROOT.rglob("*"):
        if any(part in SKIP_PARTS for part in path.parts):
            continue
        if not path.is_file() or path.resolve() == self_path:
            continue
        scanned += 1
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(ROOT))
        for name, rx in PATTERNS.items():
            for match in rx.finditer(text):
                line = text.count("\n", 0, match.start()) + 1
                findings.append((name, rel, line))
    print(f"scanned_files={scanned}")
    print(f"findings={len(findings)}")
    for name, rel, line in findings[:50]:
        print(f"{name}: {rel}:{line}")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
