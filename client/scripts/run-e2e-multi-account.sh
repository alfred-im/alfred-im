# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# E2E multi-account — stack locale (default).
# Hub: bash scripts/test.sh e2e-multi
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"
# shellcheck source=lib/e2e-local-stack.sh
source "$ROOT/scripts/lib/e2e-local-stack.sh"

BASE="${ALFRED_BASE_URL:-http://localhost:8080/}"
USE_LOCAL_STACK=0
if [[ "$BASE" == http://localhost:* ]] || [[ "$BASE" == http://127.0.0.1:* ]]; then
  USE_LOCAL_STACK=1
fi

if [[ "$USE_LOCAL_STACK" == 1 ]]; then
  e2e_ensure_supabase
  e2e_ensure_local_schema
  e2e_load_supabase_env
  export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"
  e2e_write_web_config_json

  SESSION_NAME="flutter-e2e-multi"
  tmux -f /exec-daemon/tmux.portal.conf kill-session -t "=$SESSION_NAME" 2>/dev/null || true

  if ! e2e_resolve_flutter_port; then
    echo "==> Avvio flutter web-server su :${E2E_FLUTTER_PORT} (stack locale, release)"
    tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
    tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
      "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --release --web-port=${E2E_FLUTTER_PORT} --web-hostname=0.0.0.0 \
      --dart-define=SUPABASE_URL=${SUPABASE_URL} \
      --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" C-m
    e2e_wait_flutter_ready
    e2e_warm_flutter_compile
  fi
else
  export ALFRED_BASE_URL="$BASE"
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
  echo "==> npm install (Playwright)"
  npm install
  npx playwright install chromium
fi

export ALFRED_BASE_URL="${ALFRED_BASE_URL:-$BASE}"
echo "==> Playwright multi-account (${ALFRED_BASE_URL})"
npx playwright test \
  e2e/multi-account-persist.spec.ts \
  e2e/multi-account-messages.spec.ts \
  --workers=1 \
  "$@"
