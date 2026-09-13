// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/machines/notifications/notifications_machine.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/push_conversation_key.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

import '../support/fake_messaging_services.dart';
import '../support/wiring_test_fixtures.dart';

/// Wiring: NotificationsAdapters → AuthNotificationsEffects → AuthController navigation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('notifications wiring', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;

    const agentA = ProfileSummary(
      id: 'account-a',
      username: 'agent_a',
      address: 'agent_a',
      displayName: 'Agent A',
    );
    const agentB = ProfileSummary(
      id: 'account-b',
      username: 'agent_b',
      address: 'agent_b',
      displayName: 'Agent B',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
      manager = AccountManager(storage: storage);

      sessionA = await AccountSession.createForTest(
        profile: agentA,
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(peers: [inboxPeer(agentB)]),
        profileService: MapBackedFakeProfileService.fromProfiles([agentB]),
      );
      sessionB = await AccountSession.createForTest(
        profile: agentB,
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(peers: [inboxPeer(agentA)]),
        profileService: MapBackedFakeProfileService.fromProfiles([agentA]),
      );

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      manager.restoreSessionForTest = (account) async {
        return account.userId == 'account-a' ? sessionA : sessionB;
      };
    });

    test('open chat intent con sessione pronta apre conversazione', () async {
      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      auth.notificationsAdapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          recipientUserId: 'account-b',
          peerAddress: 'agent_a',
        ),
        sessionReady: true,
        hasOpenAccount: true,
      );

      for (var i = 0;
          i < 200 &&
              auth.notificationsMachine.openChatState !=
                  NotificationsOpenChatState.idle;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(
        auth.notificationsMachine.openChatState,
        NotificationsOpenChatState.idle,
      );
      expect(auth.userId, 'account-b');
      expect(auth.activePeer?.peerAddress, 'agent_a');
    });

    test('open chat intent senza sessione pronta mette in coda', () async {
      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      auth.notificationsAdapters.onOpenChatFromNotification(
        conversation: const PushConversationKey(
          recipientUserId: 'account-b',
          peerAddress: 'agent_a',
        ),
        sessionReady: false,
        hasOpenAccount: true,
      );

      expect(
        auth.notificationsMachine.openChatState,
        NotificationsOpenChatState.queued,
      );
      expect(auth.activePeer, isNull);
    });
  });
}
