#!/usr/bin/env python3
"""Verify .cursor/rules/cursor-rules.mdc matches pre-migration backup."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKUP = ROOT / ".cursor/rules/_source.cursor-rules.md"
TARGET = ROOT / ".cursor/rules/cursor-rules.mdc"


def strip_frontmatter(text: str) -> str:
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            return text[end + 3 :].lstrip("\n")
    return text


def normalize(text: str) -> str:
    text = strip_frontmatter(text)
    text = text.replace("\r\n", "\n")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def main() -> int:
    if not BACKUP.exists():
        print("ERROR: backup missing at", BACKUP)
        return 1
    if not TARGET.exists():
        print("ERROR: target missing at", TARGET)
        return 1

    source = normalize(BACKUP.read_text(encoding="utf-8"))
    target = normalize(TARGET.read_text(encoding="utf-8"))

    if source == target:
        print("OK: cursor-rules.mdc body matches backup (normalized)")
        print(f"  chars: {len(source)}")
        return 0

    print("FAIL: content mismatch between backup and cursor-rules.mdc")
    print(f"  source length: {len(source)}")
    print(f"  target length: {len(target)}")
    min_len = min(len(source), len(target))
    for i in range(min_len):
        if source[i] != target[i]:
            print(f"  first diff at char {i}")
            print("  source:", repr(source[max(0, i - 40) : i + 40]))
            print("  target:", repr(target[max(0, i - 40) : i + 40]))
            break
    else:
        if len(source) != len(target):
            print(f"  prefix equal; length diff {len(source) - len(target)}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
