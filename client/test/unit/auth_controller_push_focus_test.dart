// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/profile_service.dart';

import '../support/fake_messaging_services.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

// PROM-PUSH-NOTIFY-030 — tap push garantisce sessione destinatario attiva
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController focusAccountForPushNotification', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;
    late AuthController auth;

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
        profileService: _FakeProfileService({
          'account-b': const ProfileSummary(
            id: 'account-b',
            username: 'agent_b',
            displayName: 'Agent B',
          ),
        }),
      );
      sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-b',
          username: 'agent_b',
          displayName: 'Agent B',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
        profileService: _FakeProfileService({
          'account-a': const ProfileSummary(
            id: 'account-a',
            username: 'agent_a',
            displayName: 'Agent A',
          ),
        }),
      );

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      manager.restoreSessionForTest = (account) async {
        return account.userId == 'account-a' ? sessionA : sessionB;
      };

      auth = AuthController(accountManager: manager)
        ..isLoading = false
        ..sessionReady = true;

      await manager.initialize();
    });

    test('reactivates session when focus id already matches recipient', () async {
      expect(auth.userId, 'account-a');

      manager.clearSessionsInRamForTest();

      final focused = await auth.focusAccountForPushNotification('account-a');

      expect(focused, isTrue);
      expect(auth.userId, 'account-a');
      expect(auth.focusedSession?.userId, 'account-a');
    });

    test('switches focus to recipient account', () async {
      final focused = await auth.focusAccountForPushNotification('account-b');

      expect(focused, isTrue);
      expect(auth.userId, 'account-b');
      expect(auth.focusedSession?.userId, 'account-b');
    });

    test('returns false when recipient is not in manifest', () async {
      final focused = await auth.focusAccountForPushNotification('missing');

      expect(focused, isFalse);
      expect(auth.userId, 'account-a');
    });

    test('tap flow: focus recipient then open peer conversation', () async {
      final focused = await auth.focusAccountForPushNotification('account-b');
      expect(focused, isTrue);

      final session = auth.focusedSession!;
      final peer = await session.profileService.findById('account-a');
      expect(peer, isNotNull);

      auth.openConversation(ChatPeer(profile: peer!));

      expect(auth.userId, 'account-b');
      expect(auth.focusedSession?.userId, 'account-b');
      expect(auth.activePeer?.profileId, 'account-a');
      expect(manager.sessions.length, 1);
      expect(manager.sessions.single.userId, 'account-b');
    });

    test('tap flow: reactivates session when focus id matches but RAM empty', () async {
      manager.clearSessionsInRamForTest();

      final focused = await auth.focusAccountForPushNotification('account-a');
      expect(focused, isTrue);

      final peer = await auth.focusedSession!.profileService.findById('account-b');
      auth.openConversation(ChatPeer(profile: peer!));

      expect(auth.userId, 'account-a');
      expect(auth.activePeer?.profileId, 'account-b');
    });
  });
}
