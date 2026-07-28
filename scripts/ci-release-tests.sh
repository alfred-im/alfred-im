# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Suite release completa su stack locale — usata da CI e `bash scripts/test.sh manual`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_ROOT="$REPO_ROOT/client"
cd "$CLIENT_ROOT"

# shellcheck source=ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"

echo "==> [1/9] Stack locale (Docker + Supabase + agenti CI)"
# shellcheck source=ci-ensure-local-stack.sh
source "$REPO_ROOT/scripts/ci-ensure-local-stack.sh"

export ALFRED_BASE_URL="${ALFRED_BASE_URL:-$CI_LOCAL_BASE_URL}"

echo "==> [2/9] SQL smoke"
bash "$REPO_ROOT/scripts/run-sql-smoke.sh"

echo "==> [3/9] integration (API)"
bash scripts/integration-multi-account.sh

echo "==> [4/9] integration-ticks"
INTEGRATION_MODE=ticks bash scripts/integration-multi-account.sh

echo "==> [5/9] integration-push"
bash scripts/integration-push.sh

echo "==> [6/9] flusso-reale"
bash scripts/run-photo-repro-e2e-local.sh

echo "==> [7/9] e2e-multi"
bash scripts/run-e2e-multi-account.sh

echo "==> [8/9] e2e-push-local + e2e-nav-local"
E2E_PUSH_REUSE_FLUTTER=1 bash scripts/run-push-e2e-local.sh
E2E_PUSH_REUSE_FLUTTER=1 bash scripts/run-e2e-nav-local.sh

echo "==> [9/9] e2e (tutti gli spec Playwright)"
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-$CI_LOCAL_BASE_URL}"
if [[ ! -x node_modules/.bin/playwright ]]; then
  npm install
  npx playwright install chromium
fi
npx playwright test e2e/ --workers=1

echo "==> stack Dart (password reset GoTrue locale)"
flutter pub get
flutter test test/integration/ \
  --tags stack \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

echo "ci_release_tests_ok"
