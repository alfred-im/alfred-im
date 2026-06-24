#!/usr/bin/env bash
# Crea le app Fly dichiarate in deploy/fly-bridges.json (idempotente).
# Richiede FLY_API_TOKEN nell'ambiente. Nessuna configurazione in dashboard.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT}/deploy/fly-bridges.json"
FLY="${FLY:-flyctl}"

command -v jq >/dev/null 2>&1 || { echo "jq richiesto"; exit 1; }
command -v "$FLY" >/dev/null 2>&1 || { echo "flyctl richiesto"; exit 1; }

if [[ -z "${FLY_API_TOKEN:-}" ]]; then
  echo "FLY_API_TOKEN non impostato"
  exit 1
fi

cd "$ROOT"

jq -c '.apps[]' "$MANIFEST" | while IFS= read -r entry; do
  app="$(echo "$entry" | jq -r '.app')"
  region="$(echo "$entry" | jq -r '.region')"

  if "$FLY" apps list --json 2>/dev/null | jq -e --arg n "$app" '.[] | select(.Name == $n)' >/dev/null; then
    echo "App già presente: $app"
  else
    echo "Creazione app: $app (region $region)"
    "$FLY" apps create "$app"
  fi
done

echo "Bootstrap completato."
