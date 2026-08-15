# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Bootstrap condiviso per e2e su stack Supabase locale (docker + supabase + env).
# shellcheck shell=bash

e2e_ensure_docker() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "==> Avvio dockerd"
  sudo dockerd >/tmp/dockerd.log 2>&1 &
  local i
  for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "docker non disponibile — vedi /tmp/dockerd.log" >&2
  exit 1
}

e2e_ensure_supabase() {
  if curl -sf -m 3 "http://127.0.0.1:54321/rest/v1/" >/dev/null 2>&1; then
    return 0
  fi
  echo "==> supabase start"
  e2e_ensure_docker
  (cd "$ROOT/.." && supabase start)
}

e2e_ensure_local_schema() {
  local has_image
  has_image="$(docker exec supabase_db_alfred psql -U postgres -d postgres -tAc \
    "SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'message_content_type' AND e.enumlabel = 'image' LIMIT 1" \
    2>/dev/null || true)"
  if [[ "$has_image" != "1" ]]; then
    echo "==> supabase db reset (schema image/video mancante)"
    (cd "$ROOT/.." && supabase db reset --yes)
  fi
}

e2e_load_supabase_env() {
  local env_file
  env_file="$(mktemp)"
  (cd "$ROOT/.." && supabase status -o env >"$env_file")
  # shellcheck disable=SC1090
  set -a && source "$env_file" && set +a
  rm -f "$env_file"
  export SUPABASE_URL="${SUPABASE_URL:-${API_URL:-}}"
  export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
  export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-${SERVICE_ROLE_KEY:-}}"
}

# Web client legge config.json all'avvio (DeployConfig); dart-define non basta su flutter web.
e2e_write_web_config_json() {
  local base="${ALFRED_BASE_URL:-http://127.0.0.1:${E2E_FLUTTER_PORT:-8080}/}"
  local url="${SUPABASE_URL:-http://127.0.0.1:54321}"
  local anon="${SUPABASE_ANON_KEY:-${ANON_KEY:-}}"
  if [[ -z "$anon" ]]; then
    echo "e2e: SUPABASE_ANON_KEY mancante — eseguire e2e_load_supabase_env" >&2
    exit 1
  fi
  mkdir -p "$ROOT/web"
  cat >"$ROOT/web/config.json" <<EOF
{
  "supabaseUrl": "${url}",
  "supabaseAnonKey": "${anon}",
  "publicBaseUrl": "${base}"
}
EOF
  echo "==> web/config.json (${url})"
  e2e_sync_web_config_to_build
}

# flutter run --release serve da build/web; config.json è gitignored e non entra nel build.
e2e_sync_web_config_to_build() {
  if [[ -f "$ROOT/web/config.json" && -d "$ROOT/build/web" ]]; then
    cp "$ROOT/web/config.json" "$ROOT/build/web/config.json"
  fi
}

e2e_warm_flutter_compile() {
  local base="$(_e2e_flutter_base)"
  echo "==> Warmup compile Flutter (main.dart.js)"
  local elapsed=0
  while (( elapsed < 180 )); do
    if curl -sf -m 30 -o /tmp/alfred-main.dart.js "${base}main.dart.js" &&
      [[ "$(wc -c < /tmp/alfred-main.dart.js)" -gt 500000 ]]; then
      e2e_sync_web_config_to_build
      echo "    main.dart.js pronto (${elapsed}s, $(wc -c < /tmp/alfred-main.dart.js) bytes)"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  echo "e2e: main.dart.js non pronto dopo 180s" >&2
  exit 1
}
