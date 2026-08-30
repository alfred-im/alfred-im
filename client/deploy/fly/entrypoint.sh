# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/bin/sh
set -eu

export GATEWAY_CONFIG_PATH="${GATEWAY_CONFIG_PATH:-/usr/share/nginx/html/config.json}"
export GATEWAY_PORT="${GATEWAY_PORT:-8091}"

python3 /opt/gateway/main.py &
gateway_pid=$!

cleanup() {
  if kill -0 "$gateway_pid" 2>/dev/null; then
    kill "$gateway_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

exec nginx -g 'daemon off;'
