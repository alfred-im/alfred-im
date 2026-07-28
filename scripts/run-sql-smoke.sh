# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Esegue tutti gli smoke SQL in supabase/tests/ sul DB locale.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_alfred$'; then
  echo "run-sql-smoke: container supabase_db_alfred assente" >&2
  exit 1
fi

bash "$REPO_ROOT/scripts/ci-bootstrap-agents.sh"

echo "==> SQL smoke (supabase/tests/*.sql)"
shopt -s nullglob
smokes=("$REPO_ROOT"/supabase/tests/*.sql)
if [[ ${#smokes[@]} -eq 0 ]]; then
  echo "run-sql-smoke: nessun file trovato" >&2
  exit 1
fi

for smoke in "${smokes[@]}"; do
  echo "    $(basename "$smoke")"
  docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
    <"$smoke" >/dev/null
done

echo "sql_smoke_ok"
