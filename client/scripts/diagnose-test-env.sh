#!/usr/bin/env bash
# Diagnostica ambiente test Cloud Agent — eseguire PRIMA di computerUse / Playwright.
# Exit 0 = OK per test API; exit 1 = problemi noti che causano hang o falsi negativi.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAIL=0
warn() { echo "WARN: $*" >&2; }
fail() { echo "FAIL: $*" >&2; FAIL=1; }
ok() { echo "OK: $*"; }

echo "==> Alfred test environment diagnosis"
echo "    $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Flutter web dev server (port 8080) ---
if curl -sf -m 5 -o /dev/null http://localhost:8080/; then
  ok "http://localhost:8080/ risponde"
else
  fail "http://localhost:8080/ non raggiungibile (flutter web-server assente?)"
fi

PORT_PID="$(lsof -t -iTCP:8080 -sTCP:LISTEN 2>/dev/null | head -1 || true)"
if [[ -n "$PORT_PID" ]]; then
  PORT_CMD="$(ps -p "$PORT_PID" -o comm= 2>/dev/null || echo unknown)"
  ok "porta 8080 → PID $PORT_PID ($PORT_CMD)"
  FLUTTER_COUNT="$(pgrep -fc 'flutter_tools.snapshot run' || true)"
  if [[ "${FLUTTER_COUNT:-0}" -gt 1 ]]; then
    fail "più processi 'flutter run' attivi ($FLUTTER_COUNT) — rischio port conflict / stato zombie"
  fi
else
  warn "impossibile identificare il processo sulla porta 8080"
fi

if tmux -f /exec-daemon/tmux.portal.conf has-session -t flutter-dev-server 2>/dev/null; then
  if tmux -f /exec-daemon/tmux.portal.conf capture-pane -t flutter-dev-server:0.0 -p | tail -20 | grep -q "Address already in use"; then
    fail "tmux flutter-dev-server: ultimo avvio fallito (port 8080 già in uso) — istanza orfana su 8080"
  else
    ok "tmux flutter-dev-server presente"
  fi
else
  warn "nessuna sessione tmux flutter-dev-server (flutter può girare fuori tmux)"
fi

# --- Chrome / computerUse (CDP 9222) ---
CHROME_PID="$(pgrep -fo 'chrome.*remote-debugging-port=9222' || true)"
if [[ -n "$CHROME_PID" ]]; then
  CHROME_AGE="$(ps -p "$CHROME_PID" -o etime= 2>/dev/null | tr -d ' ')"
  ok "Chrome GUI PID $CHROME_PID (uptime $CHROME_AGE)"
else
  warn "Chrome computerUse non in esecuzione"
fi

if curl -sf -m 3 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
  ok "Chrome CDP :9222 risponde (computerUse può automatizzare)"
else
  fail "Chrome CDP :9222 NON risponde — computerUse si blocca o va in timeout"
  echo "      → Chrome spesso resta in zombie dopo crash Flutter (schermata rossa)." >&2
  echo "      → Non riavviare flutter in loop: prima verificare CDP con questo script." >&2
fi

RENDERERS="$(pgrep -fc 'chrome --type=renderer' || true)"
if [[ "${RENDERERS:-0}" -gt 8 ]]; then
  warn "molti renderer Chrome ($RENDERERS) — possibile leak memoria dopo sessioni lunghe"
fi

# --- Playwright ---
if [[ -x node_modules/.bin/playwright ]]; then
  ok "Playwright installato in client/"
else
  warn "Playwright non installato (npm install && npx playwright install chromium)"
fi

# --- Gate standard ---
if command -v flutter >/dev/null 2>&1; then
  ok "flutter in PATH"
else
  warn "flutter non in PATH — usare /opt/flutter/bin/flutter"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "diagnose_ok — ambiente pronto per verify.sh e integration-multi-account.sh"
else
  echo "diagnose_failed — NON usare computerUse finché CDP/8080 non sono sani"
  echo "  Test consigliati senza browser:"
  echo "    bash scripts/verify.sh"
  echo "    bash scripts/integration-multi-account.sh"
fi
exit "$FAIL"
