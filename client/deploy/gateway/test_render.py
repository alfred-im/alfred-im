# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import unittest

from bootstrap import build_shell_context
from render import render_index, render_manifest_json


class GatewayRenderTest(unittest.TestCase):
    def test_renders_shell_from_bootstrap(self) -> None:
        context = build_shell_context(
            {
                "instance.display_name": "Garden Chat",
                "instance.im_server_id": "garden.example",
                "instance.branding": {
                    "short_name": "Garden",
                    "description": "Private messaging",
                    "theme_color": "#123456",
                    "background_color": "#654321",
                    "logo_url": "https://cdn.example/logo.png",
                    "favicon_url": "https://cdn.example/favicon.png",
                },
            },
        )
        html = render_index(context)
        manifest = render_manifest_json(context)

        self.assertIn("Garden Chat", html)
        self.assertIn("#123456", html)
        self.assertIn("https://cdn.example/logo.png", html)
        self.assertIn('"short_name": "Garden"', manifest)
        self.assertIn('"display": "standalone"', manifest)

    def test_fallback_defaults_when_bootstrap_empty(self) -> None:
        context = build_shell_context({})
        html = render_index(context)
        manifest = render_manifest_json(context)

        self.assertIn("Messaging", html)
        self.assertIn("Messaggistica consent-first", manifest)


if __name__ == "__main__":
    unittest.main()
