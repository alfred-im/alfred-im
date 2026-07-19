#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Push e2e Playwright — stack locale isolato (nessun dato utente sul live).
# Suite: permesso/subscribe/ricezione (push-full) + tap multi-account (push-tap-multi-account).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOCAL_VAPID_PUBLIC_KEY='BJxl1YXCAzWVKwMp3DmFoVgMzDoyWcBTLsL01MRwYPpQawss7vVUtHZW5r6fCxKfUMIkK8PTwTruf_W-M5T-oUI'

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

load_supabase_env() {
  local env_file
  env_file="$(mktemp)"
  (cd "$ROOT/.." && supabase status -o env >"$env_file")
  # shellcheck disable=SC1090
  set -a && source "$env_file" && set +a
  rm -f "$env_file"
  export DATABASE_URL="${DATABASE_URL:-${DB_URL:-}}"
  export SUPABASE_URL="${SUPABASE_URL:-${API_URL:-}}"
  export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
  export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"
}

configure_push_settings() {
  local db_url="${DATABASE_URL:-${DB_URL:-}}"
  if [[ -z "$db_url" ]]; then
    echo "DATABASE_URL/DB_URL mancante dopo supabase status" >&2
    exit 1
  fi
  local functions_base="${LOCAL_FUNCTIONS_BASE_URL:-http://kong:8000/functions/v1}"
  docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL
UPDATE alfred_delivery.push_settings
SET functions_base_url = '${functions_base}',
    vapid_public_key = '${LOCAL_VAPID_PUBLIC_KEY}',
    vapid_private_key = 'CqovlWoDdFcage2Lwa69iR3sscl69rpkqFkyN8xsNq8',
    vapid_subject = 'mailto:push-e2e@alfred.local',
    dispatch_secret = NULL,
    enabled = true
WHERE singleton = true;
SQL
}

ensure_flutter_local() {
  # shellcheck source=lib/e2e-flutter-port.sh
  source "$ROOT/scripts/lib/e2e-flutter-port.sh"

  export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

  if e2e_resolve_flutter_port; then
    return 0
  fi

  echo "==> Avvio flutter web-server locale (Supabase + VAPID e2e)"
  SESSION_NAME="flutter-push-e2e"
  tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION_NAME" 2>/dev/null || \
    tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l

  if [[ -n "$(_e2e_flutter_port_pids)" ]]; then
    echo "e2e: :${E2E_FLUTTER_PORT} ancora occupata prima di avviare Flutter" >&2
    exit 1
  fi

  local flutter_cmd
  flutter_cmd="cd $ROOT && /opt/flutter/bin/flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0"
  flutter_cmd+=" --dart-define=SUPABASE_URL=${SUPABASE_URL}"
  flutter_cmd+=" --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  flutter_cmd+=" --dart-define=VAPID_PUBLIC_KEY=${LOCAL_VAPID_PUBLIC_KEY}"
  flutter_cmd+=" --dart-define=ALFRED_DIAGNOSTIC_LOG=true"

  tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" "$flutter_cmd" C-m
  e2e_wait_flutter_ready
}

ensure_supabase
load_supabase_env

if [[ -z "${SUPABASE_URL:-}" || ! "$SUPABASE_URL" =~ localhost|127\.0\.0\.1 ]]; then
  echo "e2e-push-local richiede Supabase locale" >&2
  exit 1
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi

configure_push_settings
ensure_flutter_local

export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

echo "==> e2e-push-local ALFRED_BASE_URL=${ALFRED_BASE_URL} SUPABASE_URL=${SUPABASE_URL}"
npx playwright test e2e/push-full.spec.ts e2e/push-tap-multi-account.spec.ts "$@"
