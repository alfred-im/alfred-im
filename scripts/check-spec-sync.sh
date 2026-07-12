# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# SDD — controlli allineamento promesse ↔ repository.
# Exit 0 = OK; exit 1 = problemi da correggere prima del merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PRODUCT_DIR="docs/specs/promises/product"
SYSTEM_DIR="docs/specs/promises/system"
SURFACES_DIR="docs/specs/surfaces"
REGISTRY="docs/specs/registry.md"
ERR=0

echo "==> SDD: registry e contratti SYSTEM"
if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: manca $REGISTRY" >&2
  ERR=1
fi
for contract in docs/specs/contracts/rpc.md docs/specs/contracts/schema.md; do
  if [[ ! -f "$contract" ]]; then
    echo "ERROR: manca $contract" >&2
    ERR=1
  fi
done

echo "==> SDD: promesse SYSTEM in registry"
for sys in "$SYSTEM_DIR"/SYS-*.md; do
  [[ -f "$sys" ]] || continue
  base="$(basename "$sys" .md)"
  if ! grep -q "$base" "$REGISTRY"; then
    echo "ERROR: $base non elencato in $REGISTRY" >&2
    ERR=1
  fi
  if ! grep -q 'Promessa ID' "$sys"; then
    echo "ERROR: $sys senza campo Promessa ID" >&2
    ERR=1
  fi
  if ! grep -q 'Tracciabilità' "$sys"; then
    echo "WARN: $sys senza sezione Tracciabilità" >&2
  fi
  if ! grep -qE '\*\*SYS-[A-Z0-9-]+-[0-9]+\*\*' "$sys"; then
    echo "WARN: $sys senza SYS-ID" >&2
  fi
done

echo "==> SDD: promesse PRODUCT in registry"
for prom in "$PRODUCT_DIR"/PROM-*.md; do
  [[ -f "$prom" ]] || continue
  base="$(basename "$prom" .md)"
  if ! grep -q "$base" "$REGISTRY"; then
    echo "ERROR: $base non elencato in $REGISTRY" >&2
    ERR=1
  fi
  if ! grep -q 'Promessa ID' "$prom"; then
    echo "ERROR: $prom senza campo Promessa ID" >&2
    ERR=1
  fi
  if ! grep -qE '\*\*PROM-[A-Z0-9-]+-[0-9]+\*\*' "$prom"; then
    echo "WARN: $prom senza PROM-ID" >&2
  fi
  if ! grep -q 'Tracciabilità' "$prom"; then
    echo "WARN: $prom senza sezione Tracciabilità" >&2
  fi
done

echo "==> SDD: superfici in registry"
for surf in "$SURFACES_DIR"/SURF-*.md; do
  [[ -f "$surf" ]] || continue
  base="$(basename "$surf" .md)"
  if ! grep -q "$base" "$REGISTRY"; then
    echo "ERROR: $base non elencato in $REGISTRY" >&2
    ERR=1
  fi
  if ! grep -q 'Superficie ID' "$surf"; then
    echo "ERROR: $surf senza campo Superficie ID" >&2
    ERR=1
  fi
done

echo "==> SDD: nessun residuo cartella capabilities"
if [[ -d docs/specs/capabilities ]]; then
  echo "ERROR: docs/specs/capabilities/ ancora presente — rimuovere" >&2
  ERR=1
fi
if grep -rq 'capabilities/' docs/specs/promises docs/specs/surfaces docs/specs/registry.md docs/specs/README.md 2>/dev/null; then
  echo "ERROR: riferimenti a capabilities/ in docs/specs/" >&2
  ERR=1
fi

echo "==> SDD: contratti mailbox (no target stale)"
for contract in docs/specs/contracts/rpc.md docs/specs/contracts/schema.md; do
  if grep -q 'non su `main`' "$contract" 2>/dev/null; then
    echo "ERROR: $contract contiene ancora 'non su main' per mailbox" >&2
    ERR=1
  fi
  if grep -q '20260702120100' "$contract" 2>/dev/null && ! grep -q '20260704120000' "$contract" 2>/dev/null; then
    echo "ERROR: $contract milestone migrazioni obsoleto (manca 20260704120000)" >&2
    ERR=1
  fi
done

echo "==> SDD: smoke SQL tracciati SYS-MAILBOX"
SYS_MAILBOX="docs/specs/promises/system/SYS-MAILBOX.md"
if [[ -f "$SYS_MAILBOX" ]]; then
  for smoke in supabase/tests/mailbox_*.sql; do
    [[ -f "$smoke" ]] || continue
    base="$(basename "$smoke")"
    if ! grep -rq "$base" "$SYS_MAILBOX" docs/specs/contracts/rpc.md 2>/dev/null; then
      echo "WARN: $base non referenziato in SYS-MAILBOX o rpc.md" >&2
    fi
  done
  while IFS= read -r smoke_path; do
    [[ -n "$smoke_path" ]] || continue
    if [[ ! -f "$smoke_path" ]]; then
      echo "ERROR: SYS-MAILBOX referenzia $smoke_path ma il file non esiste" >&2
      ERR=1
    fi
  done < <(grep -oE 'supabase/tests/[a-z0-9_]+\.sql' "$SYS_MAILBOX" | sort -u)
fi

echo "==> SDD: smoke SQL tracciati SYS-GROUP"
SYS_GROUP="docs/specs/promises/system/SYS-GROUP.md"
if [[ -f "$SYS_GROUP" ]]; then
  for smoke in supabase/tests/group_*.sql supabase/tests/rpc_helper_security_smoke.sql; do
    [[ -f "$smoke" ]] || continue
    base="$(basename "$smoke")"
    if ! grep -rq "$base" "$SYS_GROUP" docs/specs/contracts/rpc.md 2>/dev/null; then
      echo "WARN: $base non referenziato in SYS-GROUP o rpc.md" >&2
    fi
  done
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  if git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^supabase/migrations/.*\.sql$'; then
    if ! git diff --name-only origin/main...HEAD 2>/dev/null | grep -q '^docs/specs/'; then
      echo "WARN: migrazioni SQL in branch ma nessun diff in docs/specs/ — verificare rpc.md / schema.md" >&2
    fi
  fi
fi

if [[ "$ERR" -ne 0 ]]; then
  echo "check-spec-sync: FAILED" >&2
  exit 1
fi

echo "check-spec-sync: OK"
