// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Feature-detect Web Push: `PushManager` su `window`, `serviceWorker` su `navigator`.
bool isWebPushEnvironmentSupported({
  required bool hasPushManagerOnWindow,
  required bool hasServiceWorkerOnNavigator,
}) {
  return hasPushManagerOnWindow && hasServiceWorkerOnNavigator;
}

/// Logica pura per decidere se tentare la registrazione push (testabile senza browser).
bool shouldAttemptPushSubscription({
  required bool isPushSupported,
  required String? notificationPermission,
}) {
  if (!isPushSupported) return false;
  if (notificationPermission == 'denied') return false;
  return true;
}

/// Dopo subscribe, la subscription va salvata solo con permesso concesso.
bool shouldPersistPushSubscription({
  required String? notificationPermission,
}) {
  return notificationPermission == 'granted';
}

/// Rileva transizione verso permesso concesso (es. ritorno da impostazioni OS).
bool notificationPermissionJustGranted({
  required String? previous,
  required String? current,
}) {
  return previous != 'granted' && current == 'granted';
}
