# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Composition tier — harness + catalogo COMP per contesti session-scoped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSITION_DIR="client/test/composition"
HARNESS="client/test/support/composition_harness.dart"
ERR=0

echo "==> Composition: harness condiviso"
if [[ ! -f "$HARNESS" ]]; then
  echo "ERROR: manca $HARNESS" >&2
  ERR=1
fi

echo "==> Composition: catalogo per contesto session-scoped"
declare -A REQUIRED=(
  [messaging]="client/test/composition/messaging_session_scope_test.dart"
)

for ctx in "${!REQUIRED[@]}"; do
  file="${REQUIRED[$ctx]}"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: contesto $ctx (session-scoped) manca $file" >&2
    ERR=1
  fi
done

echo "==> Composition: harness usa ConversationSessionAccess"
if ! grep -q 'conversation_session_access' "$HARNESS"; then
  echo "ERROR: $HARNESS deve usare conversation_session_access per session check" >&2
  ERR=1
fi

echo "==> Composition: wiring hygiene (hasValidSession bypass)"
while IFS= read -r -d '' f; do
  if grep -q 'hasValidSession: () => true' "$f" \
    && ! grep -q 'wiring-jwt-bypass-ok' "$f"; then
    echo "ERROR: $f usa hasValidSession: () => true senza commento wiring-jwt-bypass-ok" >&2
    ERR=1
  fi
done < <(find client/test/wiring -name '*_wiring_test.dart' -print0 2>/dev/null || true)

if [[ "$ERR" -ne 0 ]]; then
  echo "check-composition-sync: FAILED" >&2
  exit 1
fi

echo "check-composition-sync: OK"
