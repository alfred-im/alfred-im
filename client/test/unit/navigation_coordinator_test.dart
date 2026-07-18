// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';
import 'package:alfred_client/services/profile_service.dart';

import '../support/fake_messaging_services.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationCoordinator', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late NavigationCoordinator nav;
    late AccountSession sessionA;
    late AccountSession sessionB;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
      manager = AccountManager(storage: storage);
      nav = NavigationCoordinator(manager);

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
        inboxService: FakeInboxService(
          peers: [
            ChatPeer(
              profile: const ProfileSummary(
                id: 'account-a',
                username: 'agent_a',
                displayName: 'Agent A',
              ),
            ),
          ],
        ),
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

      await manager.initialize();
    });

    test('switchToAccount changes focus', () async {
      await nav.switchToAccount('account-b');
      expect(manager.focusUserId, 'account-b');
    });

    test('openPeerOnFocusedAccount rejects self peer', () {
      nav.openPeerOnFocusedAccount(
        ChatPeer(
          profile: const ProfileSummary(
            id: 'account-a',
            username: 'agent_a',
            displayName: 'Agent A',
          ),
        ),
      );
      expect(manager.viewState.activePeer, isNull);
    });

    test('openConversationOnAccount switches account and opens inbox peer', () async {
      final ok = await nav.openConversationOnAccount(
        accountUserId: 'account-b',
        peerProfileId: 'account-a',
        allowProfileFallback: false,
      );

      expect(ok, isTrue);
      expect(manager.focusUserId, 'account-b');
      expect(manager.viewState.activePeer?.profileId, 'account-a');
    });

    test('openConversationOnAccount rejects self peer pair', () async {
      final ok = await nav.openConversationOnAccount(
        accountUserId: 'account-a',
        peerProfileId: 'account-a',
      );

      expect(ok, isFalse);
      expect(manager.viewState.activePeer, isNull);
    });

    test('openConversationOnAccount without inbox uses profile when allowed', () async {
      final ok = await nav.openConversationOnAccount(
        accountUserId: 'account-b',
        peerProfileId: 'account-a',
        allowProfileFallback: true,
      );

      expect(ok, isTrue);
      expect(manager.focusUserId, 'account-b');
      expect(manager.viewState.activePeer?.profileId, 'account-a');
    });
  });
}
