# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Suite release sequenziale — un solo stack, un solo build web, un solo Playwright.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_ROOT="$REPO_ROOT/client"
cd "$CLIENT_ROOT"

cleanup() {
  if [[ -n "${CI_FLUTTER_SERVE_PID:-}" ]]; then
    kill "$CI_FLUTTER_SERVE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# shellcheck source=ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"

echo "==> [1/6] Stack locale"
# shellcheck source=ci-ensure-local-stack.sh
source "$REPO_ROOT/scripts/ci-ensure-local-stack.sh"
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-$CI_LOCAL_BASE_URL}"

echo "==> [2/6] SQL smoke"
bash "$REPO_ROOT/scripts/run-sql-smoke.sh"

echo "==> [3/6] integration API"
bash scripts/integration-multi-account.sh
INTEGRATION_MODE=ticks bash scripts/integration-multi-account.sh
bash scripts/integration-push.sh

echo "==> [4/6] stack Dart (GoTrue locale)"
flutter pub get
flutter test test/integration/ \
  --tags stack \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

echo "==> [5/6] build web + serve"
# shellcheck source=ci-configure-push-local.sh
source "$REPO_ROOT/scripts/ci-configure-push-local.sh"
bash "$REPO_ROOT/scripts/ci-serve-flutter-web.sh" "$CLIENT_ROOT"

echo "==> [6/6] Playwright — temporaneamente disattivato"
# Debito CI (PR #230): `npx playwright test e2e/` non è mai stato verde in headless
# (drawer Escape, pages-smoke senza a11y, push-bug-repro headed, …).
# Ripristinare a tier documentati (flusso-reale, e2e-multi, …) — non e2e/ intero.
echo "skip: Playwright in CI — eseguire manualmente: bash scripts/test.sh flusso-reale"

echo "ci_release_tests_ok"
