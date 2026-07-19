#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Gate browser navigation locale — cattura bug scope/spinner che i test Dart non vedono.
# Prerequisiti: supabase start + flutter su :8080 (vedi run-push-e2e-local.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-flutter-port.sh
source "$ROOT/scripts/lib/e2e-flutter-port.sh"

if ! curl -sf -m 3 "http://127.0.0.1:54321/rest/v1/" >/dev/null 2>&1; then
  echo "e2e-nav-local richiede supabase start" >&2
  exit 1
fi

env_file="$(mktemp)"
(cd "$ROOT/.." && supabase status -o env >"$env_file")
set -a && source "$env_file" && set +a
rm -f "$env_file"

export SUPABASE_URL="${SUPABASE_URL:-${API_URL:-}}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-http://localhost:8080/}"

if ! e2e_resolve_flutter_port; then
  echo "e2e-nav-local richiede flutter su ${ALFRED_BASE_URL}" >&2
  echo "Avvia: E2E_PUSH_REUSE_FLUTTER=0 bash scripts/run-push-e2e-local.sh (poi riusa con E2E_PUSH_REUSE_FLUTTER=1)" >&2
  exit 1
fi

if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi

echo "==> e2e-nav-local ALFRED_BASE_URL=${ALFRED_BASE_URL} SUPABASE_URL=${SUPABASE_URL}"
# workers=1: i test condividono stack locale e manifest; in parallelo sono flaky.
npx playwright test \
  e2e/inbox-open-chat.spec.ts \
  e2e/chat-inbox-parity.spec.ts \
  e2e/account-switch-restore.spec.ts \
  e2e/push-tap-multi-account.spec.ts \
  e2e/manual-push-poison-repro.spec.ts \
  --workers=1 \
  "$@"
