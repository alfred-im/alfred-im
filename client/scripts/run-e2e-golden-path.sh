#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Golden path e2e — login UI, testo, switch, foto, spunte backend.
# Prerequisiti: Docker + supabase start (avviato automaticamente se assente).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"

ensure_docker() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "==> Avvio dockerd"
  sudo dockerd >/tmp/dockerd.log 2>&1 &
  for _ in $(seq 1 30); do
    docker info >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "docker non disponibile — vedi /tmp/dockerd.log" >&2
  exit 1
}

ensure_supabase() {
  if curl -sf -m 3 "http://127.0.0.1:54321/rest/v1/" >/dev/null 2>&1; then
    return 0
  fi
  echo "==> supabase start"
  ensure_docker
  (cd "$ROOT/.." && supabase start)
}

ensure_supabase

ensure_local_schema() {
  local has_image
  has_image="$(docker exec supabase_db_alfred psql -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'message_content_type' AND e.enumlabel = 'image' LIMIT 1" \
    2>/dev/null || true)"
  if [[ "$has_image" != "1" ]]; then
    echo "==> supabase db reset (schema image/video mancante)"
    (cd "$ROOT/.." && supabase db reset --yes)
  fi
}
ensure_local_schema

env_file="$(mktemp)"
(cd "$ROOT/.." && supabase status -o env >"$env_file")
set -a && source "$env_file" && set +a
rm -f "$env_file"

export SUPABASE_URL="${SUPABASE_URL:-${API_URL:-}}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

SESSION_NAME="flutter-golden-path"
if [[ -n "$(_e2e_flutter_port_pids)" ]]; then
  echo "==> Riavvio flutter su :${E2E_FLUTTER_PORT} (stack locale)"
  echo "$(_e2e_flutter_port_pids)" | xargs -r kill
  sleep 2
fi
tmux -f /exec-daemon/tmux.portal.conf kill-session -t "=$SESSION_NAME" 2>/dev/null || true

echo "==> Avvio flutter web-server su :${E2E_FLUTTER_PORT} (stack locale)"
tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
  "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --release --web-port=${E2E_FLUTTER_PORT} --web-hostname=0.0.0.0 \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" C-m
e2e_wait_flutter_ready

warm_flutter_compile() {
  local base="$(_e2e_flutter_base)"
  echo "==> Warmup compile Flutter (main.dart.js)"
  local elapsed=0
  while (( elapsed < 180 )); do
    if curl -sf -m 30 -o /tmp/alfred-main.dart.js "${base}main.dart.js" &&
      [[ "$(wc -c < /tmp/alfred-main.dart.js)" -gt 500000 ]]; then
      echo "    main.dart.js pronto (${elapsed}s, $(wc -c < /tmp/alfred-main.dart.js) bytes)"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  echo "golden-path: main.dart.js non pronto dopo 180s" >&2
  exit 1
}
warm_flutter_compile

if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi

echo "==> golden-path e2e ALFRED_BASE_URL=${ALFRED_BASE_URL} SUPABASE_URL=${SUPABASE_URL}"
npx playwright test e2e/golden-path-multi-account.spec.ts --workers=1 "$@"
