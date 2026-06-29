#!/usr/bin/env bash
# Riavvia Chrome con CDP :9222 (computerUse). Profilo effimero per evitare zombie.
set -euo pipefail

PROFILE_DIR="${CHROME_CDP_PROFILE:-/tmp/chrome-cdp-profile}"
SESSION_NAME="chrome-cdp"

pkill -f 'google-chrome' 2>/dev/null || true
sleep 1
rm -rf "$PROFILE_DIR"

if tmux -f /exec-daemon/tmux.portal.conf has-session -t "=$SESSION_NAME" 2>/dev/null; then
  tmux -f /exec-daemon/tmux.portal.conf kill-session -t "$SESSION_NAME"
fi

tmux -f /exec-daemon/tmux.portal.conf new-session -d -s "$SESSION_NAME" -c "/workspace" -- "${SHELL:-bash}" -l
tmux -f /exec-daemon/tmux.portal.conf send-keys -t "$SESSION_NAME:0.0" \
  "DISPLAY=\${DISPLAY:-:1} /opt/google/chrome/chrome --no-sandbox --disable-dev-shm-usage --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1 --user-data-dir=${PROFILE_DIR} --no-first-run --window-size=1820,1100 about:blank" C-m

for _ in $(seq 1 15); do
  if curl -sf -m 2 http://127.0.0.1:9222/json/version >/dev/null 2>&1; then
    echo "chrome_cdp_ok profile=${PROFILE_DIR}"
    exit 0
  fi
  sleep 1
done

echo "chrome_cdp_failed — vedi tmux attach -t ${SESSION_NAME}" >&2
exit 1
