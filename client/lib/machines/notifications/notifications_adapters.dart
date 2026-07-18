// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/push_conversation_key.dart';
import 'notifications_machine.dart';

/// Mappa ingressi attuali → eventi macchina notifications.
///
/// Adapter verso navigation: [NotificationsMachine] emette [OpenChatForwarded]
/// e l'effetto chiama `AuthController.openConversationAfterPushTap`.
///
/// UML: `docs/model/uml/notifications/seq-notification-click.puml`
class NotificationsAdapters {
  NotificationsAdapters(this._machine);

  final NotificationsMachine _machine;

  void onPushSupportChecked({
    required bool supported,
    required String? permission,
  }) {
    if (!supported) {
      _machine.send(const PushUnsupportedDetected());
      return;
    }
    if (permission == 'denied') {
      _machine.send(const PermissionDeniedDetected());
      return;
    }
    _machine.send(const SubscriptionIdleReached());
  }

  void onSyncSubscriptionsRequested() {
    _machine.send(const SyncSubscriptionsRequested());
  }

  void onSubscriptionRegistered() {
    _machine.send(const SubscriptionRegistered());
  }

  void onSubscriptionSyncFailed() {
    _machine.send(const SubscriptionSyncFailed());
  }

  void onUnregisterSubscription() {
    _machine.send(const UnregisterSubscriptionRequested());
  }

  void onOpenChatIntent({
    required PushConversationKey conversation,
    required bool sessionReady,
    required bool hasOpenAccount,
  }) {
    _machine.send(
      OpenChatIntentReceived(
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
