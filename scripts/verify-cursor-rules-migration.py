#!/usr/bin/env python3
"""Verify .cursor/rules/*.mdc contain all content from pre-migration backup."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKUP = ROOT / ".cursor/rules/_source.cursor-rules.md"
RULES_DIR = ROOT / ".cursor/rules"


def strip_frontmatter(text: str) -> str:
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            return text[end + 3 :].lstrip("\n")
    return text


def normalize(text: str) -> str:
    # Drop YAML frontmatter from mdc bodies; normalize whitespace for compare
    text = strip_frontmatter(text)
    text = text.replace("\r\n", "\n")
    # Collapse multiple blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def main() -> int:
    if not BACKUP.exists():
        print("ERROR: backup missing at", BACKUP)
        return 1

    source = normalize(BACKUP.read_text(encoding="utf-8"))

    mdc_files = sorted(RULES_DIR.glob("*.mdc"))
    if not mdc_files:
        print("ERROR: no .mdc files found")
        return 1

    combined_parts: list[str] = []
    for path in mdc_files:
        combined_parts.append(normalize(path.read_text(encoding="utf-8")))

    combined = "\n\n".join(combined_parts)

    if source == combined:
        print("OK: combined .mdc content matches backup byte-for-byte (normalized)")
        print(f"  sections: {len(mdc_files)} files")
        print(f"  chars: source={len(source)} combined={len(combined)}")
        return 0

    # Detailed diff hints
    print("FAIL: content mismatch between backup and combined .mdc files")
    print(f"  source length: {len(source)}")
    print(f"  combined length: {len(combined)}")

    # Find first differing position
    min_len = min(len(source), len(combined))
    for i in range(min_len):
        if source[i] != combined[i]:
            print(f"  first diff at char {i}")
            print("  source:", repr(source[max(0, i - 40) : i + 40]))
            print("  combined:", repr(combined[max(0, i - 40) : i + 40]))
            break
    else:
        if len(source) != len(combined):
            print(f"  prefix equal; length diff {len(source) - len(combined)}")

    return 1


if __name__ == "__main__":
    sys.exit(main())
