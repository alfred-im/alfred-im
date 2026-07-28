# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Crea utenti CI con UUID fissi su stack Supabase locale (smoke SQL + integration).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"

if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_alfred$'; then
  echo "ci-bootstrap-agents: container supabase_db_alfred assente — eseguire supabase start" >&2
  exit 1
fi

echo "==> ci-bootstrap-agents (UUID fissi per smoke SQL)"
docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  <"$REPO_ROOT/scripts/ci-bootstrap-agents.sql" >/dev/null

echo "ci-bootstrap-agents OK"
