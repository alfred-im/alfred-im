# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Launcher unico release snake — stdout non bufferizzato (pipe/tee/CI).
# shellcheck source=../client/scripts/lib/e2e-local-stack.sh
# (chiamato dal parent se serve; qui solo Playwright)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

export ALFRED_SNAKE_VERBOSE=1
export PLAYWRIGHT_FORCE_TTY=1
export NODE_NO_WARNINGS=1

if [[ ! -x node_modules/.bin/playwright ]]; then
  echo "==> npm install (Playwright)"
  npm install
  npx playwright install chromium
fi

echo "[snake] $(date -Iseconds) launching Playwright (ALFRED_BASE_URL=${ALFRED_BASE_URL:-http://localhost:8080/})"

# stdbuf: line-buffer anche quando stdout non è un TTY (tee, CI, agent).
exec stdbuf -oL -eL npx playwright test e2e/release-snake.spec.ts \
  --workers=1 \
  --retries=0 \
  "$@"
