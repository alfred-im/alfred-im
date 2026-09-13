// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../machines/navigation/navigation_adapters.dart';

/// Ingresso unificato per intent esterni → [NavigationMachine].
///
/// Push tap, link conmotione e compose convergono qui prima della macchina
/// navigation / multi-account.
class ExternalIntentAdapter {
  ExternalIntentAdapter(this._navigation);

  final NavigationAdapters _navigation;

  /// Tap notifica push — PROM-PUSH-NOTIFY-030/036, SURF-NOTIFICATIONS-007.
  Future<bool> openFromPushTap({
    required String accountUserId,
    required String peerAddress,
  }) {
    return _navigation.openFromPushTap(
      accountUserId: accountUserId,
      peerAddress: peerAddress,
    );
  }

  /// Fragment `#indirizzo/chat` — PROM-SHAREABLE-LINK-004/024.
  Future<bool> openFromShareableLink({
    required String accountUserId,
    required String peerAddress,
  }) {
    return _navigation.openFromShareableLink(
      accountUserId: accountUserId,
      peerAddress: peerAddress,
    );
  }

  /// Nuovo messaggio da indirizzo (compose) sull'account in focus o specificato.
  Future<bool> openFromCompose({
    required String accountUserId,
    required String peerAddress,
    bool allowProfileFallback = true,
  }) {
    return _navigation.openFromCompose(
      accountUserId: accountUserId,
      peerAddress: peerAddress,
      allowProfileFallback: allowProfileFallback,
    );
  }
}
