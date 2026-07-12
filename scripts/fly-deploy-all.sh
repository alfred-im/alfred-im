# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLY="${FLY:-flyctl}"
command -v "$FLY" >/dev/null 2>&1 || { echo "flyctl richiesto"; exit 1; }
cd "$ROOT"
  "$FLY" deploy --remote-only -a alfred-im
