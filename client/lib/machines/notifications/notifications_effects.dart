// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Effetti collaterali del contesto notifications (implementazione in servizi esistenti).
abstract class NotificationsEffects {
  Future<bool> forwardOpenFromPushTap({
    required String recipientUserId,
    required String peerProfileId,
  });

  void persistPendingOpenChat({
    required String recipientUserId,
    required String peerProfileId,
  });

  void clearPendingOpenChat();
}
