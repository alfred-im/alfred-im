#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Hub comandi client Alfred — catalogo suite mirate (non verifica).
#
#   bash scripts/test.sh list          # elenco suite
#   bash scripts/test.sh gate          # igiene client
#
# Verifica unica: dalla root del repository, bash scripts/verify.sh
# Dettaglio: scripts/test/README.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

CMD="${1:-gate}"
shift || true

print_catalog() {
  cat <<'EOF'
Alfred client — comandi test
============================

IGIENE (non verifica):
  gate              flutter analyze + flutter test (esclusi tag stack, diagnostic)
                    → bash scripts/gate.sh [--build]
  unit              solo flutter test (esclusi tag stack)

STACK LOCALE — comandi mirati (non verifica):
  sql-smoke         tutti gli smoke SQL (supabase/tests/*.sql)
  integration       API multi-account + contratto spunte (stack locale)
  integration-ticks Solo contratto spunte (✓ / ✓✓ grigie / ✓✓ blu)
  integration-push  Smoke SQL push (stack locale)
  stack             flutter test --tags stack (GoTrue locale)

UTILITÀ:
  diagnose          ambiente flutter web / Chrome CDP / Playwright
  spec-sync         bash ../scripts/check-spec-sync.sh (SDD)

Verifica unica (root del repository):
  bash scripts/verify.sh

Esempi:
  bash scripts/test.sh gate
  bash scripts/test.sh sql-smoke
  bash scripts/test.sh integration

Documentazione: scripts/test/README.md · docs/testing/strategy.md
EOF
}

use_root_verify() {
  echo "Comando rimosso dal hub client. Verifica: bash scripts/verify.sh dalla root del repository." >&2
  exit 2
}

run_gate() {
  bash scripts/gate.sh "$@"
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

case "$CMD" in
  list|help|-h|--help)
    print_catalog
    ;;
  gate)
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
  stack|live)
    run_stack "$@"
    ;;
  diagnose|diag)
    run_diagnose "$@"
    ;;
  spec-sync|sdd)
    bash ../scripts/check-spec-sync.sh "$@"
    ;;
  verify|e2e|playwright|release|manual|all-manual|ci|flusso-reale|real-flow|integration-photo-repro|photo-repro)
    use_root_verify
    ;;
  *)
    echo "Comando sconosciuto: $CMD" >&2
    echo "Usa: bash scripts/test.sh list" >&2
    echo "Verifica: bash scripts/verify.sh dalla root del repository." >&2
    exit 2
    ;;
esac
