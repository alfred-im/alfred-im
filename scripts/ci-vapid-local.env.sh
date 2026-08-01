# Copyright (C) 2026 im.alfred
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Chiavi VAPID di test locali/CI — stesso valore di client/e2e/fixtures/vapid-local.ts
LOCAL_VAPID_PUBLIC_KEY='BJxl1YXCAzWVKwMp3DmFoVgMzDoyWcBTLsL01MRwYPpQawss7vVUtHZW5r6fCxKfUMIkK8PTwTruf_W-M5T-oUI'
LOCAL_VAPID_PRIVATE_KEY='CqovlWoDdFcage2Lwa69iR3sscl69rpkqFkyN8xsNq8'
LOCAL_VAPID_SUBJECT='mailto:push-e2e@alfred.local'

export CI_VAPID_PUBLIC_KEY="${CI_VAPID_PUBLIC_KEY:-$LOCAL_VAPID_PUBLIC_KEY}"
