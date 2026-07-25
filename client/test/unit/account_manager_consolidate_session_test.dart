// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

import '../support/fake_messaging_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountManager.consolidateSessionForAccount', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;
    var restoreCallsForA = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
      manager = AccountManager(storage: storage);

      sessionA = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-a',
          username: 'agent_a',
          displayName: 'Agent A',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
      );
      await installTestAuthSession(sessionA.client, userId: 'account-a');

      sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-b',
          username: 'agent_b',
          displayName: 'Agent B',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
      );
      await installTestAuthSession(sessionB.client, userId: 'account-b');

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      restoreCallsForA = 0;
      manager.restoreSessionForTest = (account) async {
        if (account.userId == 'account-a') {
          restoreCallsForA += 1;
          return sessionA;
        }
        return sessionB;
      };

      await manager.initialize(focusUserId: 'account-a');
    });

    test('ripristina sessione se JWT assente in RAM', () async {
      manager.clearSessionsInRamForTest();

      await manager.consolidateSessionForAccount('account-a');

      expect(restoreCallsForA, greaterThanOrEqualTo(1));
      expect(manager.isSessionReadyForAccount('account-a'), isTrue);
      expect(manager.sessions.map((s) => s.userId), ['account-a']);
    });

    test('rimuove sessioni spurie e mantiene solo account UI', () async {
      manager.injectTestSession(sessionB);
      expect(manager.sessions.length, 2);

      await manager.consolidateSessionForAccount('account-a');

      expect(manager.sessions.map((s) => s.userId), ['account-a']);
      expect(manager.isSessionReadyForAccount('account-a'), isTrue);
    });
  });
}
