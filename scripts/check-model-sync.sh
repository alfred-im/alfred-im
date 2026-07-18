# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Model governance — allineamento dominio ↔ UML ↔ statechart ↔ test.
# Exit 0 = OK; exit 1 = problemi da correggere prima del merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DOMAIN_DIR="docs/domain"
UML_DIR="docs/model/uml"
MACHINES_DIR="client/lib/machines"
TEST_DIR="client/test/unit"
ERR=0

echo "==> Model: stato modellazione per contesto"

for readme in "$DOMAIN_DIR"/*/README.md; do
  [[ -f "$readme" ]] || continue
  ctx="$(basename "$(dirname "$readme")")"

  stato_line="$(grep -E '^\*\*Stato modellazione:\*\*' "$readme" || true)"
  if [[ -z "$stato_line" ]]; then
    echo "ERROR: $readme senza riga **Stato modellazione:**" >&2
    ERR=1
    continue
  fi

  if echo "$stato_line" | grep -q '`implemented`'; then
    if ! echo "$stato_line" | grep -qE '`documented`|`wired`|`verified`'; then
      echo "ERROR: $readme usa ancora solo \`implemented\` — usare documented | wired | verified" >&2
      ERR=1
    fi
  fi

  stato="$(echo "$stato_line" | sed -n 's/^\*\*Stato modellazione:\*\* `\([^`]*\)`.*/\1/p')"
  case "$stato" in
    documented|wired|verified) ;;
    *)
      echo "ERROR: $readme stato non valido: '$stato' (atteso documented | wired | verified)" >&2
      ERR=1
      continue
      ;;
  esac

  if [[ "$stato" == "wired" || "$stato" == "verified" ]]; then
    for artifact in glossary.md commands-and-events.md; do
      if [[ ! -f "$DOMAIN_DIR/$ctx/$artifact" ]]; then
        echo "ERROR: contesto $ctx ($stato) manca $DOMAIN_DIR/$ctx/$artifact" >&2
        ERR=1
      fi
    done

    puml_count="$(find "$UML_DIR/$ctx" -maxdepth 1 -name '*.puml' 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$puml_count" -lt 1 ]]; then
      echo "ERROR: contesto $ctx ($stato) manca almeno un .puml in $UML_DIR/$ctx/" >&2
      ERR=1
    fi
  fi

  if [[ "$stato" == "wired" || "$stato" == "verified" ]]; then
    if [[ ! -d "$MACHINES_DIR/$ctx" ]]; then
      echo "ERROR: contesto $ctx ($stato) manca directory $MACHINES_DIR/$ctx/" >&2
      ERR=1
    fi
  fi

  if [[ "$stato" == "verified" ]]; then
    ctx_test="$(echo "$ctx" | tr '-' '_')"
    machine_test="$TEST_DIR/${ctx_test}_machine_test.dart"
    if [[ ! -f "$machine_test" ]]; then
      echo "ERROR: contesto $ctx (verified) manca $machine_test" >&2
      ERR=1
    fi
  fi
done

echo "==> Model: bounded-contexts.md non deve usare stato implemented"
BC="docs/domain/bounded-contexts.md"
if [[ -f "$BC" ]]; then
  if grep -q '`implemented`' "$BC"; then
    echo "ERROR: $BC contiene ancora \`implemented\` — usare documented | wired | verified" >&2
    ERR=1
  fi
fi

if [[ "$ERR" -ne 0 ]]; then
  echo "check-model-sync: FAILED" >&2
  exit 1
fi

echo "check-model-sync: OK"
