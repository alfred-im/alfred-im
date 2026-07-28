# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Push VAPID e settings per e2e su stack locale.
set -euo pipefail

LOCAL_VAPID_PUBLIC_KEY='BJxl1YXCAzWVKwMp3DmFoVgMzDoyWcBTLsL01MRwYPpQawss7vVUtHZW5r6fCxKfUMIkK8PTwTruf_W-M5T-oUI'
export CI_VAPID_PUBLIC_KEY="${CI_VAPID_PUBLIC_KEY:-$LOCAL_VAPID_PUBLIC_KEY}"

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
    vapid_private_key = 'CqovlWoDdFcage2Lwa69iR3sscl69rpkqFkyN8xsNq8',
    vapid_subject = 'mailto:push-e2e@alfred.local',
    dispatch_secret = NULL,
    enabled = true
WHERE singleton = true;
SQL

echo "ci-configure-push-local OK"
