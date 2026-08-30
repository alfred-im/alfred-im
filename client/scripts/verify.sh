# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Gate CI — stesso script in release-suite.yml.
# Exit code != 0 su qualsiasi issue di flutter analyze (inclusi livello info).
#
# Catalogo completo suite: bash scripts/test.sh list  (vedi scripts/test/README.md)
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
      echo "Usage: scripts/verify.sh [--build]"
      echo "  Default: flutter pub get, flutter analyze, flutter test"
      echo "  --build: aggiunge flutter build web (base-href /)"
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

echo "verify_ok"
