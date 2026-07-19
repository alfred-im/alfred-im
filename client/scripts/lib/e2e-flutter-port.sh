# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Helper condiviso — porta Flutter e2e (:8080 default).
# Fail-fast se occupata da processo non-Flutter; attesa avvio max 90s (non 10 min).

E2E_FLUTTER_PORT="${E2E_FLUTTER_PORT:-8080}"
E2E_FLUTTER_START_TIMEOUT_SEC="${E2E_FLUTTER_START_TIMEOUT_SEC:-90}"
E2E_FLUTTER_POLL_SEC="${E2E_FLUTTER_POLL_SEC:-2}"

_e2e_flutter_base() {
  local base="${ALFRED_BASE_URL:-http://127.0.0.1:${E2E_FLUTTER_PORT}/}"
  echo "${base%/}/"
}

_e2e_flutter_http_ready() {
  local base="$(_e2e_flutter_base)"
  curl -sf -m 3 "$base" | grep -q 'flutter_bootstrap.js' &&
    curl -sf -m 3 "$base" | grep -q 'main.dart.js'
}

_e2e_flutter_port_pids() {
  lsof -ti :"${E2E_FLUTTER_PORT}" 2>/dev/null || true
}

# Controlla subito :8080. Ritorna 0 se Flutter già pronto; 1 se va avviato; exit 1 se porta bloccata.
e2e_resolve_flutter_port() {
  local pids pid base
  base="$(_e2e_flutter_base)"
  pids="$(_e2e_flutter_port_pids)"

  if [[ -n "$pids" ]]; then
    if _e2e_flutter_http_ready; then
      pid="$(echo "$pids" | head -1)"
      echo "==> Flutter già su :${E2E_FLUTTER_PORT} (${base}, PID ${pid})"
      return 0
    fi
    pid="$(echo "$pids" | head -1)"
    if [[ "${E2E_PUSH_REUSE_FLUTTER:-}" == "1" ]]; then
      echo "e2e: :${E2E_FLUTTER_PORT} occupata da PID ${pid} ma non risponde come Flutter (${base})" >&2
      echo "Libera la porta (kill ${pid}) o riavvia il dev server." >&2
      exit 1
    fi
    echo "==> :${E2E_FLUTTER_PORT} occupata da PID ${pid} (non Flutter) — termino" >&2
    echo "$pids" | xargs -r kill
    sleep 1
    if [[ -n "$(_e2e_flutter_port_pids)" ]]; then
      echo "e2e: impossibile liberare :${E2E_FLUTTER_PORT}" >&2
      exit 1
    fi
  fi

  if _e2e_flutter_http_ready; then
    echo "==> Flutter già pronto su ${base}"
    return 0
  fi

  return 1
}

# Attende compilazione/avvio dopo `flutter run` (max 90s, poll 2s).
e2e_wait_flutter_ready() {
  local base elapsed bind_pid
  base="$(_e2e_flutter_base)"
  elapsed=0
  while (( elapsed < E2E_FLUTTER_START_TIMEOUT_SEC )); do
    if _e2e_flutter_http_ready; then
      echo "==> Flutter pronto su ${base} (${elapsed}s)"
      return 0
    fi
    bind_pid="$(_e2e_flutter_port_pids)"
    if [[ -n "$bind_pid" ]] && ! curl -sf -m 2 "$base" >/dev/null 2>&1; then
      echo "e2e: :${E2E_FLUTTER_PORT} occupata (PID ${bind_pid}) ma HTTP non risponde — fail fast" >&2
      exit 1
    fi
    sleep "$E2E_FLUTTER_POLL_SEC"
    elapsed=$((elapsed + E2E_FLUTTER_POLL_SEC))
  done
  echo "e2e: Flutter non pronto dopo ${E2E_FLUTTER_START_TIMEOUT_SEC}s su ${base} (vedi tmux flutter-push-e2e)" >&2
  exit 1
}
