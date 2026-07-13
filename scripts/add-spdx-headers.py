#!/usr/bin/env python3
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""One-shot helper: prepend GPL SPDX headers to Alfred source files."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARKER = "SPDX-License-Identifier: GPL-3.0-or-later"

DART_HEADER = """\
// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

"""

PYTHON_HEADER = """\
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""

TS_HEADER = """\
// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

"""

SH_HEADER = """\
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""

SQL_HEADER = """\
-- Copyright (C) 2026 im.alfred
--
-- SPDX-License-Identifier: GPL-3.0-or-later

"""

DOCKER_HEADER = """\
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""


def prepend(path: Path, header: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        return False
    path.write_text(header + text, encoding="utf-8")
    return True


def prepend_shell(path: Path, header: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        return False
    lines = text.splitlines(keepends=True)
    if lines and lines[0].startswith("#!"):
        path.write_text(lines[0] + header + "".join(lines[1:]), encoding="utf-8")
    else:
        path.write_text(header + text, encoding="utf-8")
    return True


def main() -> None:
    updated = 0
    patterns: list[tuple[str, str]] = [
        ("client/lib/**/*.dart", DART_HEADER),
        ("client/test/**/*.dart", DART_HEADER),
        ("bridge-xmpp/**/*.py", PYTHON_HEADER),
        ("bridge-matrix/**/*.py", PYTHON_HEADER),
        ("client/e2e/**/*.ts", TS_HEADER),
        ("client/scripts/**/*.sh", SH_HEADER),
        ("scripts/**/*.sh", SH_HEADER),
        ("supabase/**/*.sql", SQL_HEADER),
        ("**/Dockerfile", DOCKER_HEADER),
        ("fly.toml", DOCKER_HEADER),
    ]
    for pattern, header in patterns:
        for path in sorted(ROOT.glob(pattern)):
            apply = prepend_shell if path.suffix == ".sh" else prepend
            if apply(path, header):
                updated += 1
                print(f"updated: {path.relative_to(ROOT)}")
    print(f"done: {updated} files updated")


if __name__ == "__main__":
    main()
