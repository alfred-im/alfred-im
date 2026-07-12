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

BASE="${ALFRED_BASE_URL:-https://alfred-im.github.io/alfred-im/}"

if [[ "$BASE" == http://localhost:* ]] || [[ "$BASE" == http://127.0.0.1:* ]]; then
  SESSION_NAME="flutter-dev-server"
  if ! curl -sf -m 3 "${BASE%/}/" >/dev/null; then
    echo "==> Avvio flutter web-server su :8080"
    tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION_NAME" 2>/dev/null || \
      tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
    tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
      "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0" C-m
    for _ in $(seq 1 60); do
      curl -sf -m 3 "${BASE%/}/" >/dev/null && break
      sleep 5
    done
  fi
fi

export ALFRED_BASE_URL="$BASE"
echo "==> Playwright multi-account (${ALFRED_BASE_URL})"
npx playwright test e2e/multi-account-persist.spec.ts e2e/multi-account-messages.spec.ts "$@"
