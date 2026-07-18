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

// PROM-PUSH-NOTIFY-030, SURF-NOTIFICATIONS-007 — percorso reale setFocus (dispose + restore)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountManager push focus (production setFocus path)', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;
    var restoreCallsForA = 0;
    var restoreCallsForB = 0;

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
      sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-b',
          username: 'agent_b',
          displayName: 'Agent B',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
      );

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      restoreCallsForA = 0;
      restoreCallsForB = 0;
      manager.restoreSessionForTest = (account) async {
        switch (account.userId) {
          case 'account-a':
            restoreCallsForA += 1;
            return sessionA;
          case 'account-b':
            restoreCallsForB += 1;
            return sessionB;
          default:
            throw StateError('unexpected account ${account.userId}');
        }
      };
    });

    test('setFocus disposes previous session and keeps only focused session in RAM',
        () async {
      await manager.initialize(focusUserId: 'account-a');

      expect(manager.focusUserId, 'account-a');
      expect(manager.sessions.map((s) => s.userId), ['account-a']);

      await manager.setFocus('account-b');

      expect(manager.focusUserId, 'account-b');
      expect(manager.focusedSession?.userId, 'account-b');
      expect(manager.sessions.map((s) => s.userId), ['account-b']);
      expect(restoreCallsForB, 1);
    });

    test('ensureRecipientAccountActive reactivates session when focus id matches but RAM is empty',
        () async {
      await manager.initialize(focusUserId: 'account-a');
      expect(manager.focusUserId, 'account-a');
      expect(manager.focusedSession?.userId, 'account-a');

      manager.clearSessionsInRamForTest();

      await manager.ensureRecipientAccountActive('account-a');

      expect(manager.focusUserId, 'account-a');
      expect(manager.focusedSession?.userId, 'account-a');
      expect(restoreCallsForA, 2);
    });

    test('ensureRecipientAccountActive switches to recipient account', () async {
      await manager.initialize(focusUserId: 'account-a');

      await manager.ensureRecipientAccountActive('account-b');

      expect(manager.focusUserId, 'account-b');
      expect(manager.focusedSession?.userId, 'account-b');
      expect(restoreCallsForB, 1);
    });

    test('reconnectFocusedSession restores session when manifest has focus but RAM is empty',
        () async {
      await manager.initialize(focusUserId: 'account-a');
      manager.clearSessionsInRamForTest();

      await manager.reconnectFocusedSession('account-a');

      expect(manager.focusUserId, 'account-a');
      expect(manager.focusedSession?.userId, 'account-a');
      expect(restoreCallsForA, 2);
    });
  });
}
