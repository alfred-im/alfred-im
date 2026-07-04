#!/usr/bin/env bash
# Integrazione live Supabase — multi-account senza browser (no hang computerUse).
# Hub: bash scripts/test.sh integration
# Usa SOLO account agente documentati in docs/AGENT_DEBUG_ACCOUNTS.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SUPABASE_URL="${SUPABASE_URL:-https://tvwpoxxcqwphryvuyqzu.supabase.co}"
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2d3BveHhjcXdwaHJ5dnV5cXp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNTkzODAsImV4cCI6MjA5NzczNTM4MH0.u85Ze5hAtZp6P-3-LSrb0QM2nSG1cfM1I6hddCov0_M}"

AGENT1_EMAIL="${AGENT1_EMAIL:-agadriel.sexpositive+alfredagent1@gmail.com}"
AGENT1_PASS="${AGENT1_PASS:-AlfredAgentDbg1!}"
AGENT1_ID="${AGENT1_ID:-efd885fe-b36e-48fc-a796-0e3f153e40d6}"

AGENT2_EMAIL="${AGENT2_EMAIL:-agadriel.sexpositive+alfredagent2@gmail.com}"
AGENT2_PASS="${AGENT2_PASS:-AlfredAgentDbg2!}"
AGENT2_ID="${AGENT2_ID:-0a81f785-173c-4f1c-b5df-3937086a2482}"

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

count_inbox_rows() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)"
}

count_peer_messages() {
  python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)"
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

echo "==> agent1 list_inbox"
A1_INBOX_COUNT="$(rpc "$A1_JWT" list_inbox | count_inbox_rows)"
echo "    rows=$A1_INBOX_COUNT"

echo "==> agent2 list_inbox"
A2_INBOX_COUNT="$(rpc "$A2_JWT" list_inbox | count_inbox_rows)"
echo "    rows=$A2_INBOX_COUNT"

peer_body() {
  python3 -c "import json,sys; print(json.dumps({'p_peer_profile_id': sys.argv[1], 'p_limit': 100}))" "$1"
}

echo "==> agent1 list_peer_messages → agent2"
A1_PEER_COUNT="$(rpc "$A1_JWT" list_peer_messages "$(peer_body "$AGENT2_ID")" | count_peer_messages)"
echo "    messages=$A1_PEER_COUNT"

echo "==> agent2 list_peer_messages → agent1"
A2_PEER_COUNT="$(rpc "$A2_JWT" list_peer_messages "$(peer_body "$AGENT1_ID")" | count_peer_messages)"
echo "    messages=$A2_PEER_COUNT"

if [[ "$A1_PEER_COUNT" -lt 1 || "$A2_PEER_COUNT" -lt 1 ]]; then
  echo "==> reception_allowlist: agent2 consente agent1"
  ALLOW_BODY="$(python3 -c "import json; print(json.dumps({'owner_id':'${AGENT2_ID}','allowed_profile_id':'${AGENT1_ID}'}))")"
  curl -sf -m 30 -X POST "${SUPABASE_URL}/rest/v1/reception_allowlist" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${A2_JWT}" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=ignore-duplicates" \
    -d "$ALLOW_BODY" > /dev/null || true

  echo "==> mailbox: agent1 send_message_to_profile → agent2"
  SEND_BODY="$(python3 -c "import json,uuid; print(json.dumps({'p_recipient_profile_id':'${AGENT2_ID}','p_body':'integration mailbox','p_client_message_id':str(uuid.uuid4()),'p_content_type':'text'}))")"
  SEND_JSON="$(rpc "$A1_JWT" send_message_to_profile "$SEND_BODY")"
  echo "$SEND_JSON" | python3 -c "import json,sys; m=json.load(sys.stdin); assert m.get('delivered_at'), 'missing delivered_at'; print('    sent id='+m['id'][:8]+'… delivered_at ok')"

  A1_INBOX_COUNT="$(rpc "$A1_JWT" list_inbox | count_inbox_rows)"
  A2_INBOX_COUNT="$(rpc "$A2_JWT" list_inbox | count_inbox_rows)"
  echo "    inbox after send: agent1=$A1_INBOX_COUNT agent2=$A2_INBOX_COUNT"

  A1_PEER_COUNT="$(rpc "$A1_JWT" list_peer_messages "$(peer_body "$AGENT2_ID")" | count_peer_messages)"
  A2_PEER_COUNT="$(rpc "$A2_JWT" list_peer_messages "$(peer_body "$AGENT1_ID")" | count_peer_messages)"
  echo "    peer messages after send: agent1=$A1_PEER_COUNT agent2=$A2_PEER_COUNT"

  echo "==> mailbox: agent2 mark_peer_read(agent1)"
  rpc "$A2_JWT" mark_peer_read "$(python3 -c "import json; print(json.dumps({'p_peer_profile_id':'${AGENT1_ID}'}))")" > /dev/null
  READ_CHECK="$(rpc "$A1_JWT" list_peer_messages "$(peer_body "$AGENT2_ID")" | python3 -c "import json,sys; rows=json.load(sys.stdin); mine=[r for r in rows if r.get('author_id')=='${AGENT1_ID}']; assert mine, 'no outgoing'; assert mine[-1].get('read_at'), 'read_at missing on sender copy'; print('    read_at ok on sender copy')")"
  echo "$READ_CHECK"
fi

if [[ "$A1_PEER_COUNT" -lt 1 || "$A2_PEER_COUNT" -lt 1 ]]; then
  echo "integration_warn: conversazione bidirezionale vuota o monodirezionale sul backend" >&2
  echo "  (il client può essere OK mentre il DB non ha messaggi tra gli agenti)" >&2
  exit 1
fi

echo "integration_ok"
