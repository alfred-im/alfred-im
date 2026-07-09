"""Alfred Matrix bridge — Fly.io service (bootstrap)."""

from __future__ import annotations

import asyncio
import os

from aiohttp import web

SERVICE_NAME = "alfred-bridge-matrix"
PORT = int(os.environ.get("MATRIX_PORT", "8081"))


async def health(_request: web.Request) -> web.Response:
    return web.json_response({"status": "ok", "service": SERVICE_NAME})


async def run_http_server() -> None:
    app = web.Application()
    app.router.add_get("/health", health)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", PORT)
    await site.start()


async def main() -> None:
    await run_http_server()
    # TODO: matrix-nio + job da piattaforma (ADR: bridge-stateless — no stato locale)
    while True:
        await asyncio.sleep(3600)


if __name__ == "__main__":
    asyncio.run(main())
