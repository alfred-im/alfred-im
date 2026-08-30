# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import os

from aiohttp import web

from bootstrap import (
    build_shell_context,
    fetch_instance_bootstrap,
    load_gateway_config,
)
from render import render_index, render_manifest_json


async def _shell_context() -> dict:
    config = load_gateway_config()
    bootstrap = await fetch_instance_bootstrap(
        config["supabase_url"],
        config["anon_key"],
    )
    return build_shell_context(bootstrap)


async def handle_index(_request: web.Request) -> web.Response:
    context = await _shell_context()
    body = render_index(context)
    return web.Response(
        text=body,
        content_type="text/html",
        headers={"Cache-Control": "no-cache"},
    )


async def handle_manifest(_request: web.Request) -> web.Response:
    context = await _shell_context()
    body = render_manifest_json(context)
    return web.Response(
        text=body,
        content_type="application/manifest+json",
        headers={"Cache-Control": "no-cache"},
    )


async def handle_health(_request: web.Request) -> web.Response:
    return web.json_response({"status": "ok"})


def main() -> None:
    port = int(os.environ.get("GATEWAY_PORT", "8091"))
    app = web.Application()
    app.router.add_get("/", handle_index)
    app.router.add_get("/index.html", handle_index)
    app.router.add_get("/manifest.json", handle_manifest)
    app.router.add_get("/health", handle_health)
    web.run_app(app, host="127.0.0.1", port=port, print=lambda *_: None)


if __name__ == "__main__":
    main()
