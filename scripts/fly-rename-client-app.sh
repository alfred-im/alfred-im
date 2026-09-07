# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# One-time Fly.io client app rename: alfred-im-web → arkham-im (after updating fly.toml).
set -euo pipefail
FLY="${FLY:-flyctl}"
OLD_APP="${OLD_APP:-alfred-im-web}"
NEW_APP="${NEW_APP:-arkham-im}"
command -v "$FLY" >/dev/null 2>&1 || {
  echo "flyctl richiesto: https://fly.io/docs/hands-on/install-flyctl/" >&2
  exit 1
}
echo "==> Rename Fly client app $OLD_APP → $NEW_APP"
"$FLY" apps rename "$OLD_APP" "$NEW_APP"
echo "OK. Poi: bash scripts/fly-deploy-client.sh"
