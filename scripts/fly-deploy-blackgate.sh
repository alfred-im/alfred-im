# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Deploy Blackgate web client to Fly.io (second demo instance).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLY="${FLY:-flyctl}"
CONFIG="${ROOT}/client/deploy/blackgate/fly.toml"
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
echo "==> fly deploy (Blackgate client, context=repo root)"
"$FLY" deploy . --remote-only --depot=false --config "$CONFIG" --dockerfile "$DOCKERFILE" \
  --build-arg "INSTANCE_CONFIG_JSON=client/deploy/blackgate/config.json"
