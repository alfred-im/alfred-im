// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Scope di [RegisterDeviceForPush] — PROM-PUSH-NOTIFY-053.
enum PushSyncScope {
  allOpenAccounts,
  focusedAccount,
  newAccount,
}

/// Motivo policy sync — mapping in docs/domain/notifications/commands-and-events.md.
enum PushSyncReason {
  sessionReady,
  accountOpened,
  focusChanged,
  permissionGranted,
  appResumed,
  subscriptionRotated,
}
