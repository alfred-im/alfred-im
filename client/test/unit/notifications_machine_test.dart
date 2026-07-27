// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/notifications/notifications_adapters.dart';
import 'package:alfred_client/machines/notifications/notifications_effects.dart';
import 'package:alfred_client/machines/notifications/notifications_machine.dart';
import 'package:alfred_client/models/push_conversation_key.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingEffects implements NotificationsEffects {
  int forwardCount = 0;
  int persistCount = 0;
  int clearCount = 0;
  bool forwardResult = true;

  @override
  Future<bool> forwardOpenFromPushTap({
    required String recipientUserId,
    required String peerProfileId,
  }) async {
    forwardCount++;
    return forwardResult;
  }

  @override
  void persistPendingOpenChat({
    required String recipientUserId,
    required String peerProfileId,
  }) {
    persistCount++;
  }

  @override
  void clearPendingOpenChat() {
    clearCount++;
  }
}

void main() {
  group('NotificationsMachine subscription', () {
    test('SyncSubscriptions da idle → syncing → active', () {
      final machine = NotificationsMachine();

      machine.send(const SyncSubscriptionsRequested());
      expect(machine.subscriptionState, NotificationsSubscriptionState.syncing);

      machine.send(const PushRegistrationSucceeded());
      expect(machine.subscriptionState, NotificationsSubscriptionState.active);
    });

    test('permission denied blocca sync', () {
      final machine = NotificationsMachine()
        ..send(const PermissionDeniedDetected());

      machine.send(const SyncSubscriptionsRequested());
      expect(
        machine.subscriptionState,
        NotificationsSubscriptionState.permissionDenied,
      );
    });

    test('push unsupported blocca sync', () {
      final machine = NotificationsMachine()
        ..send(const PushUnsupportedDetected());

      machine.send(const SyncSubscriptionsRequested());
      expect(
        machine.subscriptionState,
        NotificationsSubscriptionState.pushUnsupported,
      );
    });

    test('sync fallita torna idle', () {
      final machine = NotificationsMachine()
        ..send(const SyncSubscriptionsRequested());

      machine.send(const PushRegistrationFailed());
      expect(machine.subscriptionState, NotificationsSubscriptionState.idle);
    });

    test('unregister da active torna idle', () {
      final machine = NotificationsMachine()
        ..send(const SyncSubscriptionsRequested())
        ..send(const PushRegistrationSucceeded());

      machine.send(const UnregisterSubscriptionRequested());
      expect(machine.subscriptionState, NotificationsSubscriptionState.idle);
    });
  });

  group('NotificationsMachine open chat', () {
    test('session not ready → queued + persist', () {
      final effects = _RecordingEffects();
      final machine = NotificationsMachine(effects: effects);
      final adapters = NotificationsAdapters(machine);

      adapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          ownerUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
        sessionReady: false,
        hasOpenAccount: true,
      );

      expect(machine.openChatState, NotificationsOpenChatState.queued);
      expect(effects.persistCount, 1);
      expect(effects.forwardCount, 0);
    });

    test('session ready → forward OpenFromPushTap', () async {
      final effects = _RecordingEffects();
      final machine = NotificationsMachine(effects: effects);
      final adapters = NotificationsAdapters(machine);

      adapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          ownerUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
        sessionReady: true,
        hasOpenAccount: true,
      );

      await Future<void>.delayed(Duration.zero);
      expect(effects.forwardCount, 1);
      expect(machine.openChatState, NotificationsOpenChatState.idle);
      expect(effects.clearCount, greaterThan(0));
    });

    test('account non aperto → rejected', () {
      final effects = _RecordingEffects();
      final machine = NotificationsMachine(effects: effects);
      final adapters = NotificationsAdapters(machine);

      adapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          ownerUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
        sessionReady: true,
        hasOpenAccount: false,
      );

      expect(machine.openChatState, NotificationsOpenChatState.idle);
      expect(effects.forwardCount, 0);
      expect(effects.clearCount, 1);
    });

    test('SessionBecameReady drena coda in-memory durante processing', () async {
      final effects = _RecordingEffects();
      final machine = NotificationsMachine(effects: effects);
      final adapters = NotificationsAdapters(machine);

      adapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          ownerUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
        sessionReady: true,
        hasOpenAccount: true,
      );
      adapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          ownerUserId: 'user-c',
          peerProfileId: 'peer-d',
        ),
        sessionReady: true,
        hasOpenAccount: true,
      );

      expect(machine.openChatState, NotificationsOpenChatState.queued);

      await Future<void>.delayed(Duration.zero);
      expect(effects.forwardCount, 2);
      expect(machine.openChatState, NotificationsOpenChatState.idle);
    });
  });
}
