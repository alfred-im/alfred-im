# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, select_autoescape

TEMPLATE_DIR = Path(__file__).resolve().parent / "templates"


def _environment() -> Environment:
    return Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        autoescape=select_autoescape(enabled_extensions=("html", "xml")),
    )


def render_index(context: dict[str, Any]) -> str:
    template = _environment().get_template("index.html.j2")
    return template.render(**context)


def render_manifest(context: dict[str, Any]) -> str:
    template = _environment().get_template("manifest.json.j2")
    return template.render(**context)


def render_manifest_json(context: dict[str, Any]) -> str:
    rendered = render_manifest(context)
    # Validate JSON before serving.
    json.loads(rendered)
    return rendered
