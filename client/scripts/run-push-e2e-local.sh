#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Push e2e Playwright — stack locale isolato (nessun dato utente sul live).
# Suite: permesso/subscribe/ricezione (push-full) + tap multi-account (push-tap-multi-account).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"
# shellcheck source=lib/e2e-local-stack.sh
source "$ROOT/scripts/lib/e2e-local-stack.sh"

e2e_ensure_supabase
e2e_load_supabase_env
export DATABASE_URL="${DATABASE_URL:-${DB_URL:-}}"

if [[ -z "${SUPABASE_URL:-}" || ! "$SUPABASE_URL" =~ localhost|127\.0\.0\.1 ]]; then
  echo "e2e-push-local richiede Supabase locale" >&2
  exit 1
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi

# shellcheck source=../../scripts/ci-configure-push-local.sh
source "$REPO_ROOT/scripts/ci-configure-push-local.sh"

ensure_flutter_local() {
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
  flutter_cmd+=" --dart-define=VAPID_PUBLIC_KEY=${CI_VAPID_PUBLIC_KEY}"
  flutter_cmd+=" --dart-define=ALFRED_DIAGNOSTIC_LOG=true"

  tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" "$flutter_cmd" C-m
  e2e_wait_flutter_ready
}

ensure_flutter_local
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

echo "==> e2e-push-local ALFRED_BASE_URL=${ALFRED_BASE_URL} SUPABASE_URL=${SUPABASE_URL}"
npx playwright test e2e/push-full.spec.ts e2e/push-tap-multi-account.spec.ts "$@"
