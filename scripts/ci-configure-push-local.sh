# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Push VAPID e settings per e2e su stack locale.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ci-vapid-local.env.sh
source "$REPO_ROOT/scripts/ci-vapid-local.env.sh"

db_url="${DATABASE_URL:-${DB_URL:-}}"
if [[ -z "$db_url" ]]; then
  echo "ci-configure-push-local: DATABASE_URL mancante" >&2
  exit 1
fi

functions_base="${LOCAL_FUNCTIONS_BASE_URL:-http://kong:8000/functions/v1}"
docker exec -i supabase_db_alfred psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<SQL
UPDATE alfred_delivery.push_settings
SET functions_base_url = '${functions_base}',
    vapid_public_key = '${CI_VAPID_PUBLIC_KEY}',
    vapid_private_key = '${LOCAL_VAPID_PRIVATE_KEY}',
    vapid_subject = '${LOCAL_VAPID_SUBJECT}',
    dispatch_secret = NULL,
    enabled = true
WHERE singleton = true;
SQL

echo "ci-configure-push-local OK"
