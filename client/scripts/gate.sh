#!/usr/bin/env bash
# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Igiene client — flutter analyze + test isolati. NON è verifica.
# Verifica unica: dalla root del repository, bash scripts/verify.sh
#
# Catalogo comandi client: bash scripts/test.sh list  (vedi scripts/test/README.md)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> check-spec-sync (SDD)"
bash "$ROOT/../scripts/check-spec-sync.sh"

echo "==> check-model-sync (dominio / UML / statechart)"
bash "$ROOT/../scripts/check-model-sync.sh"

echo "==> check-composition-sync (Provider / session scope)"
bash "$ROOT/../scripts/check-composition-sync.sh"

RUN_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --build)
      RUN_BUILD=1
      ;;
    -h|--help)
      echo "Usage: scripts/gate.sh [--build]"
      echo "  Igiene client: flutter pub get, flutter analyze, flutter test"
      echo "  --build: aggiunge flutter build web (base-href /)"
      echo "  NON è verifica. Verifica unica: bash scripts/verify.sh (root del repo)"
      exit 0
      ;;
    *)
      echo "Argomento sconosciuto: $arg" >&2
      exit 2
      ;;
  esac
done

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test"
flutter test \
  test/composition \
  test/unit \
  test/widget \
  test/wiring \
  --exclude-tags live

if [[ "$RUN_BUILD" == 1 ]]; then
  echo "==> flutter build web"
  flutter build web --release --base-href "/"
fi

echo "gate_ok"
