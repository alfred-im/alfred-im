# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Smoke test: build client gateway image and verify nginx serves SPA + config.json.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

IMAGE="${IMAGE:-alfred-client-smoke}"
PORT="${CLIENT_SMOKE_PORT:-18090}"
DOCKERFILE="${ROOT}/client/deploy/fly/Dockerfile"

echo "==> docker build (client/deploy/fly/Dockerfile, context=repo root)"
docker build -f "$DOCKERFILE" -t "$IMAGE" .

cid=""
cleanup() {
  if [[ -n "$cid" ]]; then
    docker rm -f "$cid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "==> docker run nginx :${PORT}"
cid="$(docker run -d -p "${PORT}:8080" "$IMAGE")"

for _ in $(seq 1 60); do
  if curl -sf -m 2 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

html="$(curl -sf -m 10 "http://127.0.0.1:${PORT}/")"
config="$(curl -sf -m 10 "http://127.0.0.1:${PORT}/config.json")"
manifest="$(curl -sf -m 10 "http://127.0.0.1:${PORT}/manifest.json")"

echo "$html" | grep -q 'flutter_bootstrap.js'
echo "$config" | grep -q 'supabaseUrl'
echo "$manifest" | grep -q '"display": "standalone"'

echo "OK client index (flutter_bootstrap.js)"
echo "OK config.json"
echo "OK manifest.json"
