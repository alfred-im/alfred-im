#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# ★ Tier «flusso utente reale» — valida il prodotto (il gate no).
# Hub: bash scripts/test.sh flusso-reale
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"
# shellcheck source=lib/e2e-local-stack.sh
source "$ROOT/scripts/lib/e2e-local-stack.sh"

e2e_ensure_supabase
e2e_ensure_local_schema
e2e_load_supabase_env
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

# Push settings (syncPushSubscriptions al resume richiede push abilitato)
db_url="${DATABASE_URL:-${DB_URL:-}}"
if [[ -n "$db_url" ]]; then
  docker exec -i supabase_db_alfred psql -U postgres -d postgres -q -c \
    "UPDATE alfred_delivery.push_settings SET enabled = true WHERE singleton = true;" 2>/dev/null || true
fi

SESSION_NAME="flutter-photo-repro-e2e"
if ! e2e_resolve_flutter_port; then
  tmux -f /exec-daemon/tmux.portal.conf kill-session -t "=$SESSION_NAME" 2>/dev/null || true
  tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
  tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
    "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --release --web-port=${E2E_FLUTTER_PORT:-8080} --web-hostname=0.0.0.0 \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" C-m
  e2e_wait_flutter_ready
  e2e_warm_flutter_compile
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi

export SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY ALFRED_BASE_URL
echo "==> ★ flusso-reale: photo-resume e2e (${ALFRED_BASE_URL})"
npx playwright test e2e/photo-resume-session-repro.spec.ts --workers=1 "$@"
