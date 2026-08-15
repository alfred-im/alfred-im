# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# Integrazione API multi-account su stack Supabase locale (nessun backend live).
# Hub: bash scripts/test.sh integration | integration-ticks
# Garantisce: ✓ singola (rifiuto allow list), ✓✓ grigie (deliver worker), ✓✓ blu (read_receipt worker).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

# shellcheck source=../../scripts/ci-agents.env.sh
source "$REPO_ROOT/scripts/ci-agents.env.sh"
# shellcheck source=lib/e2e-local-stack.sh
source "$ROOT/scripts/lib/e2e-local-stack.sh"

e2e_ensure_supabase
e2e_load_supabase_env
# bootstrap-once: guard in ci-bootstrap-agents.sh (/tmp/alfred-ci-bootstrap.done)
bash "$REPO_ROOT/scripts/ci-bootstrap-agents.sh"

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"

AGENT1_EMAIL="${AGENT1_EMAIL:-$CI_AGENT1_EMAIL}"
AGENT1_PASS="${AGENT1_PASS:-$CI_AGENT1_PASS}"
AGENT1_ID="${AGENT1_ID:-$CI_AGENT1_ID}"

AGENT2_EMAIL="${AGENT2_EMAIL:-$CI_AGENT2_EMAIL}"
AGENT2_PASS="${AGENT2_PASS:-$CI_AGENT2_PASS}"
AGENT2_ID="${AGENT2_ID:-$CI_AGENT2_ID}"

if [[ ! "$SUPABASE_URL" =~ localhost|127\.0\.0\.1 ]]; then
  echo "integration richiede stack Supabase locale (SUPABASE_URL=${SUPABASE_URL})" >&2
  exit 1
fi

MODE="${INTEGRATION_MODE:-full}"

login() {
  local email="$1" password="$2"
  curl -sf -m 30 -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}"
}

rpc() {
  local jwt="$1" fn="$2" body="${3:-}"
  if [[ -z "$body" ]]; then body="{}"; fi
  local tmp http
  tmp="$(mktemp)"
  http="$(curl -s -m 30 -o "$tmp" -w '%{http_code}' -X POST "${SUPABASE_URL}/rest/v1/rpc/${fn}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${jwt}" \
    -H "Content-Type: application/json" \
    -d "$body")"
  if [[ "$http" != "200" && "$http" != "204" ]]; then
    echo "RPC ${fn} failed HTTP ${http}: $(cat "$tmp")" >&2
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp"
  rm -f "$tmp"
}

rest_delete() {
  local jwt="$1" path="$2"
  local http
  http="$(curl -s -m 30 -o /dev/null -w '%{http_code}' -X DELETE "${SUPABASE_URL}/rest/v1/${path}" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${jwt}")"
  if [[ "$http" != "204" && "$http" != "200" ]]; then
    echo "DELETE ${path} failed HTTP ${http}" >&2
    return 1
  fi
}

rest_insert_allow() {
  local jwt="$1" archive_user="$2" allowed="$3"
  curl -sf -m 30 -X POST "${SUPABASE_URL}/rest/v1/reception_allowlist" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${jwt}" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=ignore-duplicates" \
    -d "{\"archive_user_id\":\"${archive_user}\",\"allowed_profile_id\":\"${allowed}\"}" > /dev/null
}

peer_body() {
  python3 -c "import json,sys; print(json.dumps({'p_peer_profile_id': sys.argv[1], 'p_limit': 200}))" "$1"
}

send_body() {
  local recipient="$1" body="$2" client_id="$3"
  python3 -c "import json,sys; print(json.dumps({'p_recipient_profile_id':sys.argv[1],'p_body':sys.argv[2],'p_client_message_id':sys.argv[3],'p_content_type':'text'}))" \
    "$recipient" "$body" "$client_id"
}

mark_read_body() {
  python3 -c "import json,sys; print(json.dumps({'p_peer_profile_id': sys.argv[1]}))" "$1"
}

assert_ticks_contract() {
  local a1_jwt="$1" a2_jwt="$2"
  local stamp reject_id deliver_id read_id

  stamp="$(date +%s)"
  reject_id="int-ticks-reject-${stamp}-$$"
  deliver_id="int-ticks-deliver-${stamp}-$$"
  read_id="int-ticks-read-${stamp}-$$"

  echo "==> ticks contract: fase 1 — rifiuto allow list (solo ✓)"
  rest_delete "$a2_jwt" "reception_allowlist?archive_user_id=eq.${AGENT2_ID}&allowed_profile_id=eq.${AGENT1_ID}" || true

  rpc "$a1_jwt" send_message_to_profile "$(send_body "$AGENT2_ID" "integration ticks reject" "$reject_id")" | python3 -c "
import json,sys
m=json.load(sys.stdin)
assert m.get('archive_user_id') and m.get('logical_message_id'), 'missing sender row'
assert m.get('delivered_at') is None, 'reject: delivered_at must be null (single tick)'
assert m.get('read_at') is None, 'reject: read_at must be null'
print('    reject: single tick ok (delivered_at=null)')
"

  echo "==> ticks contract: fase 2 — allow list + deliver worker (✓✓ grigie)"
  rest_insert_allow "$a2_jwt" "$AGENT2_ID" "$AGENT1_ID"

  rpc "$a1_jwt" send_message_to_profile "$(send_body "$AGENT2_ID" "integration ticks deliver" "$deliver_id")" | python3 -c "
import json,sys
m=json.load(sys.stdin)
assert m.get('delivered_at'), 'deliver: delivered_at required (double grey)'
assert m.get('read_at') is None, 'deliver: read_at must be null before read'
lam=m['logical_message_id']
print(f'    deliver: double grey ok lambda={lam[:8]}…')
"

  echo "==> ticks contract: fase 3 — mark_peer_read + read_receipt worker (✓✓ blu)"
  SEND_JSON="$(rpc "$a1_jwt" send_message_to_profile "$(send_body "$AGENT2_ID" "integration ticks read" "$read_id")")"
  export LAMBDA
  LAMBDA="$(echo "$SEND_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['logical_message_id'])")"
  rpc "$a2_jwt" mark_peer_read "$(mark_read_body "$AGENT1_ID")" > /dev/null

  rpc "$a1_jwt" list_peer_messages "$(peer_body "$AGENT2_ID")" | python3 -c "
import json,sys,os
lam=os.environ['LAMBDA']
agent1=os.environ['AGENT1_ID']
rows=json.load(sys.stdin)
mine=[r for r in rows if r.get('logical_message_id')==lam and r.get('author_id')==agent1]
assert mine, 'no outgoing row for read test'
row=mine[0]
assert row.get('delivered_at'), 'read: delivered_at must be set'
assert row.get('read_at'), 'read: read_at must be set on sender (double blue via delivery)'
print('    read: double blue ok on sender copy')
"

  rpc "$a2_jwt" list_peer_messages "$(peer_body "$AGENT1_ID")" | python3 -c "
import json,sys,os
lam=os.environ['LAMBDA']
agent1=os.environ['AGENT1_ID']
rows=json.load(sys.stdin)
inc=[r for r in rows if r.get('logical_message_id')==lam and r.get('author_id')==agent1]
assert inc and inc[0].get('read_at'), 'recipient incoming read_at must be set locally'
print('    read: recipient local read_at ok')
"
}

echo "==> integration multi-account (API only)"

echo "==> login agent1"
A1_JSON="$(login "$AGENT1_EMAIL" "$AGENT1_PASS")"
A1_JWT="$(echo "$A1_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")"
A1_UID="$(echo "$A1_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['user']['id'])")"
echo "    user_id=$A1_UID"

echo "==> login agent2"
A2_JSON="$(login "$AGENT2_EMAIL" "$AGENT2_PASS")"
A2_JWT="$(echo "$A2_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")"
A2_UID="$(echo "$A2_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['user']['id'])")"
echo "    user_id=$A2_UID"

if [[ "$MODE" == "ticks" ]]; then
  export AGENT1_ID AGENT2_ID
  assert_ticks_contract "$A1_JWT" "$A2_JWT"
  echo "integration_ticks_ok"
  exit 0
fi

echo "==> agent1 list_inbox"
A1_INBOX_COUNT="$(rpc "$A1_JWT" list_inbox | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)")"
echo "    rows=$A1_INBOX_COUNT"

echo "==> agent2 list_inbox"
A2_INBOX_COUNT="$(rpc "$A2_JWT" list_inbox | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)")"
echo "    rows=$A2_INBOX_COUNT"

echo "==> agent1 list_peer_messages → agent2"
A1_PEER_COUNT="$(rpc "$A1_JWT" list_peer_messages "$(peer_body "$AGENT2_ID")" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)")"
echo "    messages=$A1_PEER_COUNT"

echo "==> agent2 list_peer_messages → agent1"
A2_PEER_COUNT="$(rpc "$A2_JWT" list_peer_messages "$(peer_body "$AGENT1_ID")" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)")"
echo "    messages=$A2_PEER_COUNT"

export AGENT1_ID AGENT2_ID
assert_ticks_contract "$A1_JWT" "$A2_JWT"

if [[ "$A1_PEER_COUNT" -lt 1 || "$A2_PEER_COUNT" -lt 1 ]]; then
  echo "integration_warn: storico peer monodirezionale o vuoto (ticks contract comunque ok)" >&2
fi

echo "integration_ok"
