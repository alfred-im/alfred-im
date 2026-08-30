# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from defaults import (
    DEFAULT_BACKGROUND_COLOR,
    DEFAULT_DESCRIPTION,
    DEFAULT_DISPLAY_NAME,
    DEFAULT_FAVICON_URL,
    DEFAULT_IM_SERVER_ID,
    DEFAULT_LOGO_URL,
    DEFAULT_SHORT_NAME,
    DEFAULT_THEME_COLOR,
)


def load_gateway_config() -> dict[str, str]:
    config_path = os.environ.get(
        "GATEWAY_CONFIG_PATH",
        "/usr/share/nginx/html/config.json",
    )
    raw = json.loads(Path(config_path).read_text(encoding="utf-8"))
    supabase_url = str(raw.get("supabaseUrl", "")).strip()
    anon_key = str(raw.get("supabaseAnonKey", "")).strip()
    if not supabase_url or not anon_key:
        raise RuntimeError("config.json must define supabaseUrl and supabaseAnonKey")
    return {"supabase_url": supabase_url, "anon_key": anon_key}


async def fetch_instance_bootstrap(
    supabase_url: str,
    anon_key: str,
) -> dict[str, Any]:
    import aiohttp

    url = f"{supabase_url.rstrip('/')}/rest/v1/rpc/get_instance_bootstrap"
    headers = {
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}",
        "Content-Type": "application/json",
    }
    timeout = aiohttp.ClientTimeout(total=5)
    try:
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, headers=headers, json={}) as response:
                if response.status != 200:
                    return {}
                payload = await response.json()
                if isinstance(payload, dict):
                    return payload
    except (aiohttp.ClientError, TimeoutError, json.JSONDecodeError):
        return {}
    return {}


def _read_string(raw: dict[str, Any], key: str, fallback: str) -> str:
    value = raw.get(key)
    if isinstance(value, str):
        trimmed = value.strip()
        if trimmed:
            return trimmed
    return fallback


def _read_branding(raw: dict[str, Any]) -> dict[str, Any]:
    value = raw.get("instance.branding")
    if isinstance(value, dict):
        return value
    return {}


def build_shell_context(bootstrap: dict[str, Any]) -> dict[str, Any]:
    branding = _read_branding(bootstrap)
    display_name = _read_string(
        bootstrap,
        "instance.display_name",
        DEFAULT_DISPLAY_NAME,
    )
    short_name = branding.get("short_name")
    if not isinstance(short_name, str) or not short_name.strip():
        short_name = display_name if display_name else DEFAULT_SHORT_NAME
    else:
        short_name = short_name.strip()

    description = branding.get("description")
    if not isinstance(description, str) or not description.strip():
        description = DEFAULT_DESCRIPTION
    else:
        description = description.strip()

    theme_color = branding.get("theme_color")
    if not isinstance(theme_color, str) or not theme_color.strip():
        theme_color = DEFAULT_THEME_COLOR
    else:
        theme_color = theme_color.strip()

    background_color = branding.get("background_color")
    if not isinstance(background_color, str) or not background_color.strip():
        background_color = DEFAULT_BACKGROUND_COLOR
    else:
        background_color = background_color.strip()

    logo_url = branding.get("logo_url")
    if not isinstance(logo_url, str) or not logo_url.strip():
        logo_url = DEFAULT_LOGO_URL
    else:
        logo_url = logo_url.strip()

    favicon_url = branding.get("favicon_url")
    if not isinstance(favicon_url, str) or not favicon_url.strip():
        favicon_url = DEFAULT_FAVICON_URL
    else:
        favicon_url = favicon_url.strip()

    manifest_name = display_name
    icon_src = logo_url

    return {
        "display_name": display_name,
        "im_server_id": _read_string(
            bootstrap,
            "instance.im_server_id",
            DEFAULT_IM_SERVER_ID,
        ),
        "short_name": short_name,
        "description": description,
        "theme_color": theme_color,
        "background_color": background_color,
        "logo_url": logo_url,
        "favicon_url": favicon_url,
        "manifest_name": manifest_name,
        "icon_src": icon_src,
    }
