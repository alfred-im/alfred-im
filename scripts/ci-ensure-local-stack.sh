# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Avvia Docker + Supabase locale, bootstrap agenti CI, esporta env.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT_ROOT="$REPO_ROOT/client"

# shellcheck source=ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"
# shellcheck source=client/scripts/lib/e2e-local-stack.sh
source "$CLIENT_ROOT/scripts/lib/e2e-local-stack.sh"

ROOT="$CLIENT_ROOT"
export ROOT

e2e_ensure_supabase
e2e_ensure_local_schema
e2e_load_supabase_env

export SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"
export DATABASE_URL="${DATABASE_URL:-${DB_URL:-}}"
export ALFRED_BASE_URL="${ALFRED_BASE_URL:-$CI_LOCAL_BASE_URL}"

# bootstrap-once: guard in ci-bootstrap-agents.sh (/tmp/alfred-ci-bootstrap.done)
bash "$REPO_ROOT/scripts/ci-bootstrap-agents.sh"

echo "ci_local_stack_ok SUPABASE_URL=${SUPABASE_URL} ALFRED_BASE_URL=${ALFRED_BASE_URL}"
