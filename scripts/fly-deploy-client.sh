# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Deploy Arkham web client to Fly.io (demo instance).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLY="${FLY:-flyctl}"
CONFIG="${ROOT}/client/deploy/arkham/fly.toml"
DOCKERFILE="${ROOT}/client/deploy/shared/Dockerfile"

command -v "$FLY" >/dev/null 2>&1 || {
  echo "flyctl richiesto: https://fly.io/docs/hands-on/install-flyctl/" >&2
  exit 1
}

if [[ ! -f "$CONFIG" ]]; then
  echo "Manca $CONFIG" >&2
  exit 1
fi

cd "$ROOT"
echo "==> fly deploy (Arkham client, context=repo root)"
# --depot=false: Flutter build fails on Fly Depot (~3s, trap context); legacy builder works.
"$FLY" deploy . --remote-only --depot=false --config "$CONFIG" --dockerfile "$DOCKERFILE" \
  --build-arg "INSTANCE_CONFIG_JSON=client/deploy/arkham/config.json"
