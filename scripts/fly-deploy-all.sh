#!/usr/bin/env bash
# Deploy di tutti i bridge Fly dichiarati in deploy/fly-bridges.json.
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

"${ROOT}/scripts/fly-bootstrap.sh"

jq -c '.apps[]' "$MANIFEST" | while IFS= read -r entry; do
  dir="$(echo "$entry" | jq -r '.dir')"
  app="$(echo "$entry" | jq -r '.app')"
  echo "Deploy $app da ./$dir ..."
  "$FLY" deploy "./${dir}" --remote-only -a "$app"
done

echo "Deploy completato."
