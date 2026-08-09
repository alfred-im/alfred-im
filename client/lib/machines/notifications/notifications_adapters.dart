// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/push_conversation_key.dart';
import 'notifications_machine.dart';

/// Mappa ingressi attuali → eventi macchina notifications (open chat).
///
/// Adapter verso navigation: l'effetto [NotificationsEffects.forwardOpenFromPushTap]
/// chiama `AuthController.openConversationAfterPushTap` → `openFromPushTap`.
///
/// UML: `docs/model/uml/notifications/seq-notification-click.puml`
class NotificationsAdapters {
  NotificationsAdapters(this._machine);

  final NotificationsMachine _machine;

  void onOpenChatFromNotification({
    required PushConversationKey conversation,
    required bool sessionReady,
    required bool hasOpenAccount,
  }) {
    _machine.send(
      OpenChatFromNotification(
        recipientUserId: conversation.ownerUserId,
        peerProfileId: conversation.peerProfileId,
        sessionReady: sessionReady,
        hasOpenAccount: hasOpenAccount,
      ),
    );
  }

  void onSessionBecameReady() {
    _machine.send(const SessionBecameReady());
  }
}
