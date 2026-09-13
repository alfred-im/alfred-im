// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

import '../support/fake_messaging_services.dart';

// PROM-PUSH-NOTIFY-030 — tap push garantisce sessione destinatario attiva
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController push tap flow', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;
    late AuthController auth;

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

      auth = AuthController(accountManager: manager);
      await auth.initialize();
    });

    test('tap flow: focus recipient then open peer conversation', () async {
      final opened = await auth.openConversationAfterPushTap(
        recipientUserId: 'account-b',
        peerAddress: 'agent_a',
      );
      expect(opened, isTrue);

      expect(auth.userId, 'account-b');
      expect(auth.focusedSession?.userId, 'account-b');
      expect(auth.activePeer?.peerAddress, 'agent_a');
      expect(manager.sessions.length, 1);
      expect(manager.sessions.single.userId, 'account-b');
    });

    test('tap flow: reactivates session when focus id matches but RAM empty', () async {
      manager.clearSessionsInRamForTest();

      final opened = await auth.openConversationAfterPushTap(
        recipientUserId: 'account-a',
        peerAddress: 'agent_b',
      );
      expect(opened, isTrue);

      expect(auth.userId, 'account-a');
      expect(auth.activePeer?.peerAddress, 'agent_b');
    });
  });
}
