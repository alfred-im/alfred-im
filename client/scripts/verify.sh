#!/usr/bin/env bash
# Verifica standard client Flutter — stesso gate della CI (deploy-pages.yml).
# Exit code != 0 su qualsiasi issue di flutter analyze (inclusi livello info).
#
# Catalogo completo suite: bash scripts/test.sh list  (vedi scripts/test/README.md)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> check-spec-sync (SDD)"
bash "$ROOT/../scripts/check-spec-sync.sh"

RUN_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --build)
      RUN_BUILD=1
      ;;
    -h|--help)
      echo "Usage: scripts/verify.sh [--build]"
      echo "  Default: flutter pub get, flutter analyze, flutter test"
      echo "  --build: aggiunge flutter build web (base-href GitHub Pages)"
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
flutter test --exclude-tags live

if [[ "$RUN_BUILD" == 1 ]]; then
  echo "==> flutter build web"
  flutter build web --release --base-href "/XmppTest/"
fi

echo "verify_ok"
