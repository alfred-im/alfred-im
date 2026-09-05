# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Hub test Alfred — catalogo e launcher per tutte le suite.
#
#   bash scripts/test.sh list          # elenco suite
#   bash scripts/test.sh gate          # gate CI (default)
#   bash scripts/test.sh manual        # suite release completa (stack locale)
#
# Dettaglio: scripts/test/README.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

CMD="${1:-gate}"
shift || true

print_catalog() {
  cat <<'EOF'
Alfred client — suite test
==========================

GATE (CI) — igiene codice (mock/fake, niente browser):
  gate              flutter analyze + flutter test (esclusi tag stack, diagnostic)
                    → bash scripts/verify.sh [--build]

STACK LOCALE (CI + release) — supabase start + Flutter :8080:
  sql-smoke         tutti gli smoke SQL (supabase/tests/*.sql)
  flusso-reale      ★ TELEFONO: 4 user + gruppo → galleria → resume → foto → DB
  integration       API multi-account + contratto spunte (stack locale)
  integration-ticks Solo contratto spunte (✓ / ✓✓ grigie / ✓✓ blu)
  integration-push  Smoke SQL push (stack locale)
  e2e               release snake Playwright (unico serpente, retries=0)
  e2e-multi         Playwright multi-account (persist + messaggi)
  e2e-push-local    Playwright push — ricezione + tap multi-account
  e2e-nav-local     Playwright navigation — inbox tap + push poison
  stack             flutter test --tags stack (GoTrue locale)
  release           suite completa stack (alias: manual, ci)
  manual            alias di release

UTILITÀ:
  diagnose          ambiente flutter web / Chrome CDP / Playwright
  spec-sync         bash ../scripts/check-spec-sync.sh (SDD)

Esempi:
  bash scripts/test.sh gate
  bash scripts/test.sh release
  bash scripts/test.sh sql-smoke

Documentazione: scripts/test/README.md
EOF
}

run_gate() {
  bash scripts/verify.sh "$@"
}

run_sql_smoke() {
  bash "$REPO_ROOT/scripts/run-sql-smoke.sh" "$@"
}

run_integration() {
  bash scripts/integration-multi-account.sh "$@"
}

run_integration_ticks() {
  INTEGRATION_MODE=ticks bash scripts/integration-multi-account.sh "$@"
}

ensure_local_stack_env() {
  # shellcheck source=../../scripts/ci-ensure-local-stack.sh
  source "$REPO_ROOT/scripts/ci-ensure-local-stack.sh"
}

run_e2e() {
  ensure_local_stack_env
  # shellcheck source=lib/e2e-flutter-port.sh
  source "$ROOT/scripts/lib/e2e-flutter-port.sh"
  # shellcheck source=lib/e2e-local-stack.sh
  source "$ROOT/scripts/lib/e2e-local-stack.sh"
  e2e_write_web_config_json

  # Riavvio pulito: config.json locale + build release (non debug DDC).
  local stale_pids
  stale_pids="$(_e2e_flutter_port_pids)"
  if [[ -n "$stale_pids" ]]; then
    echo "==> Termino Flutter su :${E2E_FLUTTER_PORT} (e2e richiede release + config.json)"
    echo "$stale_pids" | xargs -r kill
    sleep 2
  fi

  if ! e2e_resolve_flutter_port; then
    SESSION_NAME="flutter-e2e-all"
    tmux -f /exec-daemon/tmux.portal.conf kill-session -t "=$SESSION_NAME" 2>/dev/null || true
    tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "$ROOT" -- "${SHELL:-bash}" -l
    tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
      "cd $ROOT && /opt/flutter/bin/flutter run -d web-server --release --web-port=${E2E_FLUTTER_PORT:-8080} --web-hostname=0.0.0.0 \
      --dart-define=SUPABASE_URL=${SUPABASE_URL} \
      --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
      --dart-define=ALFRED_DIAGNOSTIC_LOG=true" C-m
    e2e_wait_flutter_ready
    e2e_warm_flutter_compile
  fi

  if [[ ! -x node_modules/.bin/playwright ]]; then
    echo "==> npm install (Playwright)"
    npm install
    npx playwright install chromium
  fi
  echo "==> Playwright release snake (ALFRED_BASE_URL=${ALFRED_BASE_URL})"
  npx playwright test e2e/release-snake.spec.ts --workers=1 --retries=0 "$@"
}

run_e2e_multi() {
  bash scripts/run-e2e-multi-account.sh "$@"
}

run_stack() {
  ensure_local_stack_env
  echo "==> flutter test --tags stack"
  flutter pub get
  flutter test test/integration/ \
    --tags stack \
    --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
    "$@"
}

run_diagnose() {
  bash scripts/diagnose-test-env.sh "$@"
}

run_real_flow() {
  echo "==> ★ Flusso utente reale — valida il prodotto (browser + DB + tap veri)"
  bash scripts/integration-photo-session-repro.sh "$@"
}

run_release() {
  bash "$REPO_ROOT/scripts/ci-release-tests.sh" "$@"
}

case "$CMD" in
  list|help|-h|--help)
    print_catalog
    ;;
  gate|verify)
    run_gate "$@"
    ;;
  sql-smoke|sql)
    run_sql_smoke "$@"
    ;;
  unit)
    flutter pub get
    flutter test --exclude-tags stack "$@"
    ;;
  integration|integration-multi)
    run_integration "$@"
    ;;
  integration-ticks|ticks)
    run_integration_ticks "$@"
    ;;
  integration-push|push)
    bash scripts/integration-push.sh "$@"
    ;;
  flusso-reale|real-flow|integration-photo-repro|photo-repro)
    run_real_flow "$@"
    ;;
  e2e-push-local|push-local)
    bash scripts/run-push-e2e-local.sh "$@"
    ;;
  e2e-nav-local|nav-local)
    bash scripts/run-e2e-nav-local.sh "$@"
    ;;
  e2e|playwright)
    run_e2e "$@"
    ;;
  e2e-multi|multi-account|multi)
    run_e2e_multi "$@"
    ;;
  stack|live)
    run_stack "$@"
    ;;
  diagnose|diag)
    run_diagnose "$@"
    ;;
  spec-sync|sdd)
    bash ../scripts/check-spec-sync.sh "$@"
    ;;
  release|manual|all-manual|ci)
    run_release "$@"
    ;;
  *)
    echo "Comando sconosciuto: $CMD" >&2
    echo "Usa: bash scripts/test.sh list" >&2
    exit 2
    ;;
esac
