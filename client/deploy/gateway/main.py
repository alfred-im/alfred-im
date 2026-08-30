# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from bootstrap import build_shell_context, fetch_instance_bootstrap, load_gateway_config
from render import render_index, render_manifest_json


class GatewayHandler(BaseHTTPRequestHandler):
    server_version = "AlfredShellGateway/1.0"

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/index.html"):
            self._respond_shell()
            return
        if self.path == "/manifest.json":
            self._respond_manifest()
            return
        if self.path == "/health":
            self._respond_json(200, {"status": "ok"})
            return
        self.send_error(404)

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _shell_context(self) -> dict[str, Any]:
        config = load_gateway_config()
        bootstrap = fetch_instance_bootstrap(
            config["supabase_url"],
            config["anon_key"],
        )
        return build_shell_context(bootstrap)

    def _respond_shell(self) -> None:
        body = render_index(self._shell_context()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _respond_manifest(self) -> None:
        body = render_manifest_json(self._shell_context()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/manifest+json")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _respond_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(os.environ.get("GATEWAY_PORT", "8091"))
    host = os.environ.get("GATEWAY_HOST", "127.0.0.1")
    server = ThreadingHTTPServer((host, port), GatewayHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
