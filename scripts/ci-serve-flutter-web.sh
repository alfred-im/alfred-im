# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Build web release + serve statico su :8080 (più veloce di flutter run in CI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_ROOT="${1:-$REPO_ROOT/client}"
PORT="${E2E_FLUTTER_PORT:-8080}"
cd "$CLIENT_ROOT"
# shellcheck source=ci-vapid-local.env.sh
source "$REPO_ROOT/scripts/ci-vapid-local.env.sh"

: "${SUPABASE_URL:?SUPABASE_URL richiesto}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY richiesto}"

echo "==> flutter build web (release, stack locale)"
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=VAPID_PUBLIC_KEY="${CI_VAPID_PUBLIC_KEY}"

if lsof -ti :"${PORT}" >/dev/null 2>&1; then
  lsof -ti :"${PORT}" | xargs -r kill
  sleep 1
fi

echo "==> serve build/web su :${PORT}"
python3 -m http.server "${PORT}" --bind 0.0.0.0 --directory build/web >/tmp/flutter-web-serve.log 2>&1 &
SERVE_PID=$!
export CI_FLUTTER_SERVE_PID="$SERVE_PID"

for _ in $(seq 1 30); do
  if curl -sf -m 2 "http://127.0.0.1:${PORT}/" | grep -q 'flutter_bootstrap.js'; then
    echo "ci-serve-flutter-web OK pid=${SERVE_PID} url=http://127.0.0.1:${PORT}/"
    exit 0
  fi
  sleep 1
done

echo "ci-serve-flutter-web: server non pronto" >&2
cat /tmp/flutter-web-serve.log >&2 || true
kill "$SERVE_PID" 2>/dev/null || true
exit 1
