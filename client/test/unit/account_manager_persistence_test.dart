// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // spec: PROM-MULTI-ACCOUNT-003, PROM-MULTI-ACCOUNT-006, PROM-MULTI-ACCOUNT-015
  group('AccountSession declarative persistence', () {
    late AccountStorageService storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
    });

    Future<AccountSession> sessionFor({
      required String id,
      required String username,
      required String refreshToken,
    }) async {
      final session = await AccountSession.createForTest(
        profile: ProfileSummary(
          id: id,
          username: username,
          displayName: username,
        ),
        refreshToken: refreshToken,
      );
      session.wireStorage(storage);
      return session;
    }

    test('persistOpenAccount writes one entry with explicit token', () async {
      final sessionA = await sessionFor(
        id: 'agent-a',
        username: 'alfredagent1',
        refreshToken: 'refresh-agent-a',
      );

      await sessionA.persistOpenAccount(refreshToken: 'refresh-agent-a');

      final stored = await storage.loadAccounts();
      expect(stored.length, 1);
      expect(stored.single.userId, 'agent-a');
      expect(stored.single.refreshToken, 'refresh-agent-a');
    });

    test('adopt A then B keeps both entries via upsert', () async {
      final manager = AccountManager(storage: storage);
      final sessionA = await sessionFor(
        id: 'agent-a',
        username: 'alfredagent1',
        refreshToken: 'refresh-agent-a',
      );
      final sessionB = await sessionFor(
        id: 'agent-b',
        username: 'alfredagent2',
        refreshToken: 'refresh-agent-b',
      );

      manager.injectTestSession(sessionA);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-agent-a');

      manager.injectTestSession(sessionB);
      await sessionB.persistOpenAccount(refreshToken: 'refresh-agent-b');

      final stored = await storage.loadAccounts();
      expect(stored.length, 2);
      expect(
        stored.map((a) => a.userId).toSet(),
        {'agent-a', 'agent-b'},
      );
    });

    test('removeAccount drops only the closed entry', () async {
      final manager = AccountManager(storage: storage);
      final sessionA = await sessionFor(
        id: 'agent-a',
        username: 'alfredagent1',
        refreshToken: 'refresh-agent-a',
      );
      final sessionB = await sessionFor(
        id: 'agent-b',
        username: 'alfredagent2',
        refreshToken: 'refresh-agent-b',
      );

      manager.injectTestSession(sessionA);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-agent-a');
      manager.injectTestSession(sessionB);
      await sessionB.persistOpenAccount(refreshToken: 'refresh-agent-b');

      await manager.removeAccount('agent-b');

      final stored = await storage.loadAccounts();
      expect(stored.length, 1);
      expect(stored.single.userId, 'agent-a');
      expect(stored.single.refreshToken, 'refresh-agent-a');
    });

    test('persistOpenAccount updates only the matching entry', () async {
      final sessionA = await sessionFor(
        id: 'agent-a',
        username: 'alfredagent1',
        refreshToken: 'refresh-agent-a-v1',
      );
      final sessionB = await sessionFor(
        id: 'agent-b',
        username: 'alfredagent2',
        refreshToken: 'refresh-agent-b',
      );

      await sessionA.persistOpenAccount(refreshToken: 'refresh-agent-a-v1');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-agent-b');
      await sessionA.persistOpenAccount(refreshToken: 'refresh-agent-a-v2');

      final stored = await storage.loadAccounts();
      expect(stored.length, 2);
      expect(
        stored.firstWhere((a) => a.userId == 'agent-a').refreshToken,
        'refresh-agent-a-v2',
      );
      expect(
        stored.firstWhere((a) => a.userId == 'agent-b').refreshToken,
        'refresh-agent-b',
      );
    });

    test('wireStorage enables token refresh persistence', () async {
      final session = await sessionFor(
        id: 'agent-a',
        username: 'alfredagent1',
        refreshToken: 'refresh-agent-a-v1',
      );
      await session.persistOpenAccount(refreshToken: 'refresh-agent-a-v1');
      await session.persistOpenAccount(refreshToken: 'refresh-agent-a-v2');

      final stored = await storage.loadAccounts();
      expect(stored.single.refreshToken, 'refresh-agent-a-v2');
    });

    test('initialize removes entries with empty refresh token', () async {
      await storage.upsertAccount(
        (await sessionFor(
          id: 'agent-broken',
          username: 'broken',
          refreshToken: 'ignored',
        ))
            .toOpenAccount()
            .copyWith(refreshToken: ''),
      );

      final manager = AccountManager(storage: storage);
      await manager.initialize(focusUserId: null);

      final stored = await storage.loadAccounts();
      expect(stored, isEmpty);
    });
  });
}
