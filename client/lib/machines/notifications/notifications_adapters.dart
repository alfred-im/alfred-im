// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/push_conversation_key.dart';
import 'notifications_machine.dart';

/// Mappa ingressi attuali → eventi macchina notifications.
///
/// Adapter verso navigation: l'effetto [NotificationsEffects.forwardOpenFromPushTap]
/// chiama `AuthController.openConversationAfterPushTap` → `openFromPushTap`.
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

  void onPushRegistrationSucceeded() {
    _machine.send(const PushRegistrationSucceeded());
  }

  void onPushRegistrationFailed() {
    _machine.send(const PushRegistrationFailed());
  }

  void onUnregisterSubscription() {
    _machine.send(const UnregisterSubscriptionRequested());
  }

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
