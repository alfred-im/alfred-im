# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# E2E multi-account — default demo live (flusso utente mobile).
# Hub: bash scripts/test.sh e2e-multi
# Locale: ALFRED_BASE_URL=http://localhost:8080/ bash scripts/test.sh e2e-multi
# test1/test2: ALFRED_ACCOUNT1_EMAIL=... ALFRED_ACCOUNT1_PASSWORD=... ALFRED_ACCOUNT1_LABEL=test1 ...
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"

BASE="${ALFRED_BASE_URL:-https://alfred-im.github.io/alfred-im/}"

if [[ "$BASE" == http://localhost:* ]] || [[ "$BASE" == http://127.0.0.1:* ]]; then
  export ALFRED_BASE_URL="$BASE"
  if ! e2e_resolve_flutter_port; then
    SESSION_NAME="flutter-dev-server"
    if [[ -n "$(_e2e_flutter_port_pids)" ]]; then
      echo "e2e-multi: :${E2E_FLUTTER_PORT} occupata — libera la porta prima di avviare Flutter" >&2
      exit 1
    fi
    echo "==> Avvio flutter web-server su :${E2E_FLUTTER_PORT}"
    tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION_NAME" 2>/dev/null || \
      tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
    tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
      "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --web-port=${E2E_FLUTTER_PORT} --web-hostname=0.0.0.0" C-m
    e2e_wait_flutter_ready
  fi
fi

export ALFRED_BASE_URL="$BASE"
echo "==> Playwright multi-account (${ALFRED_BASE_URL})"
npx playwright test e2e/multi-account-persist.spec.ts e2e/multi-account-messages.spec.ts "$@"
