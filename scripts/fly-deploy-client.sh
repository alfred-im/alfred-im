# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Deploy Alfred web client to Fly.io (separate app from bridge workers).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLY="${FLY:-flyctl}"
CONFIG="${ROOT}/client/deploy/fly/fly.toml"
DOCKERFILE="${ROOT}/client/deploy/fly/Dockerfile"

command -v "$FLY" >/dev/null 2>&1 || {
  echo "flyctl richiesto: https://fly.io/docs/hands-on/install-flyctl/" >&2
  exit 1
}

if [[ ! -f "$CONFIG" ]]; then
  echo "Manca $CONFIG" >&2
  exit 1
fi

cd "$ROOT"
echo "==> fly deploy (client gateway, context=repo root)"
"$FLY" deploy . --remote-only --config "$CONFIG" --dockerfile "$DOCKERFILE"
