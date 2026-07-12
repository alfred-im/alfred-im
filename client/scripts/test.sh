# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Hub test Alfred — catalogo e launcher per tutte le suite.
#
#   bash scripts/test.sh list          # elenco suite
#   bash scripts/test.sh gate          # gate CI (default)
#   bash scripts/test.sh manual        # integration + e2e-multi + live
#
# Dettaglio: scripts/test/README.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CMD="${1:-gate}"
shift || true

print_catalog() {
  cat <<'EOF'
Alfred client — suite test
==========================

GATE (CI, sempre):
  gate              flutter analyze + flutter test (esclusi live)
                    → bash scripts/verify.sh [--build]

MANUALE (rete / browser, non in CI):
  integration       API Supabase live — agent1↔agent2 + contratto spunte
  integration-ticks Solo contratto spunte (✓ / ✓✓ grigie / ✓✓ blu + allow list)
  e2e               tutti i Playwright (client/e2e/)
  e2e-multi         Playwright multi-account (persist + messages + DB)
  live              flutter test --tags live
  manual            integration + e2e-multi + live (in sequenza)

UTILITÀ:
  diagnose          ambiente flutter web / Chrome CDP / Playwright
  spec-sync         bash ../scripts/check-spec-sync.sh (SDD catalogo/contratti)

Esempi:
  bash scripts/test.sh gate
  bash scripts/test.sh e2e-multi
  ALFRED_BASE_URL=http://localhost:8080/ bash scripts/test.sh e2e-multi
  bash scripts/test.sh manual

Documentazione: scripts/test/README.md
EOF
}

run_gate() {
  bash scripts/verify.sh "$@"
}

run_integration() {
  bash scripts/integration-multi-account.sh "$@"
}

run_integration_ticks() {
  INTEGRATION_MODE=ticks bash scripts/integration-multi-account.sh "$@"
}

run_e2e() {
  if [[ ! -x node_modules/.bin/playwright ]]; then
    echo "==> npm install (Playwright)"
    npm install
    npx playwright install chromium
  fi
  echo "==> Playwright e2e/ (ALFRED_BASE_URL=${ALFRED_BASE_URL:-https://alfred-im.github.io/alfred-im/})"
  npx playwright test e2e/ "$@"
}

run_e2e_multi() {
  bash scripts/run-e2e-multi-account.sh "$@"
}

run_live() {
  echo "==> flutter test --tags live"
  flutter pub get
  flutter test --tags live "$@"
}

run_diagnose() {
  bash scripts/diagnose-test-env.sh "$@"
}

run_manual() {
  echo "==> Suite manuali (integration → e2e-multi → live)"
  run_integration
  run_e2e_multi
  run_live
}

case "$CMD" in
  list|help|-h|--help)
    print_catalog
    ;;
  gate|ci|verify)
    run_gate "$@"
    ;;
  unit)
    flutter pub get
    flutter test --exclude-tags live "$@"
    ;;
  integration|integration-multi)
    run_integration "$@"
    ;;
  integration-ticks|ticks)
    run_integration_ticks "$@"
    ;;
  e2e|playwright)
    run_e2e "$@"
    ;;
  e2e-multi|multi-account|multi)
    run_e2e_multi "$@"
    ;;
  live)
    run_live "$@"
    ;;
  diagnose|diag)
    run_diagnose "$@"
    ;;
  spec-sync|sdd)
    bash ../scripts/check-spec-sync.sh "$@"
    ;;
  manual|all-manual)
    run_manual
    ;;
  *)
    echo "Comando sconosciuto: $CMD" >&2
    echo "Usa: bash scripts/test.sh list" >&2
    exit 2
    ;;
esac
