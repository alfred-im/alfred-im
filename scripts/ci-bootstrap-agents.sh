# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Crea utenti CI con UUID fissi su stack Supabase locale (smoke SQL + integration).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"

ALFRED_CI_BOOTSTRAP_DONE="${ALFRED_CI_BOOTSTRAP_DONE:-/tmp/alfred-ci-bootstrap.done}"
if [[ -f "$ALFRED_CI_BOOTSTRAP_DONE" ]]; then
  echo "==> ci-bootstrap-agents (skip — già eseguito in questa run CI)"
  exit 0
fi

if ! docker ps --format '{{.Names}}' | grep -q '^supabase_db_alfred$'; then
  echo "ci-bootstrap-agents: container supabase_db_alfred assente — eseguire supabase start" >&2
  exit 1
fi

echo "==> ci-bootstrap-agents (UUID fissi per smoke SQL)"
docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  <"$REPO_ROOT/scripts/ci-bootstrap-agents.sql" >/dev/null

touch "$ALFRED_CI_BOOTSTRAP_DONE"
echo "ci-bootstrap-agents OK"
