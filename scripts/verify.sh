#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Unica verifica del repository: igiene client + stack release (Playwright snake).
# client/scripts/gate.sh è solo igiene — non è verifica.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GATE_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --build)
      GATE_ARGS+=(--build)
      ;;
    -h|--help)
      echo "Usage: bash scripts/verify.sh [--build]"
      echo
      echo "Unica verifica del repository (dalla root):"
      echo "  [1] Igiene client — client/scripts/gate.sh"
      echo "  [2] Stack release — scripts/ci-release-tests.sh (SQL, integration, Playwright snake)"
      echo
      echo "  --build  inoltra a gate.sh (flutter build web)"
      echo
      echo "gate.sh da solo è igiene, non verifica."
      exit 0
      ;;
    *)
      echo "Argomento sconosciuto: $arg" >&2
      echo "Usa: bash scripts/verify.sh [--build]" >&2
      exit 2
      ;;
  esac
done

echo "==> Verifica [1/2] igiene client (gate.sh)"
bash "$REPO_ROOT/client/scripts/gate.sh" "${GATE_ARGS[@]}"

echo "==> Verifica [2/2] stack release (ci-release-tests.sh)"
bash "$REPO_ROOT/scripts/ci-release-tests.sh"

echo "verify_ok"
