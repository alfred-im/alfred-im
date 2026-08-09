# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Smoke SQL push su stack locale.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

# shellcheck source=lib/e2e-local-stack.sh
source "$ROOT/scripts/lib/e2e-local-stack.sh"

e2e_ensure_supabase
e2e_load_supabase_env

export SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"

if [[ ! "$SUPABASE_URL" =~ localhost|127\.0\.0\.1 ]]; then
  echo "integration-push richiede stack Supabase locale" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_alfred$'; then
  echo "integration-push: container supabase_db_alfred assente" >&2
  exit 1
fi

# bootstrap-once: guard in ci-bootstrap-agents.sh (/tmp/alfred-ci-bootstrap.done)
bash "$REPO_ROOT/scripts/ci-bootstrap-agents.sh"

echo "==> Smoke SQL push (stack locale)"
for smoke in "$REPO_ROOT"/supabase/tests/push_*.sql; do
  [[ -f "$smoke" ]] || continue
  echo "    $(basename "$smoke")"
  docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
    <"$smoke" >/dev/null
done

echo "integration-push OK"
