#!/usr/bin/env python3
"""Move .cursor-rules.md into a single .cursor/rules/cursor-rules.mdc (alwaysApply)."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / ".cursor/rules/_source.cursor-rules.md"
TARGET = ROOT / ".cursor/rules/cursor-rules.mdc"
RULES_DIR = ROOT / ".cursor/rules"
POINTER = ROOT / ".cursor-rules.md"

FRONTMATTER = """---
description: Regole di sviluppo Alfred — fonte autoritativa (regola 0, SDD, modello, build, workflow)
alwaysApply: true
---

"""


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"ERROR: backup missing at {SOURCE}")

    body = SOURCE.read_text(encoding="utf-8")
    TARGET.write_text(FRONTMATTER + body, encoding="utf-8")

    for path in sorted(RULES_DIR.glob("[0-9]*.mdc")):
        path.unlink()
        print(f"removed {path.name}")

    POINTER.write_text(
        """# Regole importanti per lo sviluppo

> **Spostate in `.cursor/rules/cursor-rules.mdc`** (injection Cursor via `alwaysApply`).
> Questo file resta come puntatore per link esistenti nel repository.

Vedi [.cursor/rules/cursor-rules.mdc](.cursor/rules/cursor-rules.mdc).

Backup pre-migrazione: `.cursor/rules/_source.cursor-rules.md`.
""",
        encoding="utf-8",
    )

    print(f"wrote {TARGET.relative_to(ROOT)} ({TARGET.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
