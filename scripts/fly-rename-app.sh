# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
# One-time Fly.io app rename: xmpptest → alfred-im (after updating fly.toml).
set -euo pipefail
FLY="${FLY:-flyctl}"
OLD_APP="${OLD_APP:-xmpptest}"
NEW_APP="${NEW_APP:-alfred-im}"
command -v "$FLY" >/dev/null 2>&1 || { echo "flyctl richiesto: https://fly.io/docs/hands-on/install-flyctl/"; exit 1; }
echo "==> Rename Fly app $OLD_APP → $NEW_APP"
"$FLY" apps rename "$OLD_APP" "$NEW_APP"
echo "OK. Poi: bash scripts/fly-deploy-all.sh"
