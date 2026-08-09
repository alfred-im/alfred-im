// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/services/profile_service.dart';

import '../support/fake_messaging_services.dart';
import '../support/wiring_test_fixtures.dart';

const _agent1 = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _agent2 = '0a81f785-173c-4f1c-b5df-3937086a2482';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

ChatPeer _peer(ProfileSummary profile) => ChatPeer.fromProfile(profile: profile);

ProfileSummary _profile(String id, String username) => ProfileSummary(
      id: id,
      username: username,
      displayName: username,
    );

ChatMessage _msg(String id, String body, String senderId) => ChatMessage(
      id: id,
      body: body,
      timeLabel: '12:00',
      isMine: false,
      senderId: senderId,
      createdAt: DateTime.utc(2026, 6, 29, 12),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // spec: PROM-MULTI-ACCOUNT-010, PROM-MULTI-ACCOUNT-020
  group('Multi-account mutual chat scenario', () {
    late AccountManager manager;
    late FakeMessageService messageService;
    late FakeInboxService inboxService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      final client = createTestSupabaseClient();
      messageService = FakeMessageService(client);
      inboxService = FakeInboxService();

      messageService.messagesByConversation[conversationKey(
        userId: _agent1,
        peerProfileId: _agent2,
      )] = [
        _msg('1', 'ciao da agent1', _agent1),
        _msg('2', 'risposta agent2', _agent2),
      ];
      messageService.messagesByConversation[conversationKey(
        userId: _agent2,
        peerProfileId: _agent1,
      )] = [
        _msg('1', 'ciao da agent1', _agent1),
        _msg('2', 'risposta agent2', _agent2),
      ];

      manager.restoreSessionForTest = (account) async {
        final profile = account.profile;
        return AccountSession.createForTest(
          profile: profile,
          client: client,
          inboxService: inboxService,
          profileService: _FakeProfileService({
            _agent1: _profile(_agent1, 'alfredagent1'),
            _agent2: _profile(_agent2, 'alfredagent2'),
          }),
        );
      };
    });

    Future<AuthController> wiredAuth() async {
      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: _agent1, username: 'alfredagent1'),
          openAccount(userId: _agent2, username: 'alfredagent2'),
        ],
        focusUserId: _agent1,
      );
      final wiredManager = AccountManager(storage: storage)
        ..restoreSessionForTest = manager.restoreSessionForTest;
      final auth = await createWiredAuthController(manager: wiredManager);
      await auth.initialize();
      return auth;
    }

    test('focus switch keeps per-account chat and loads correct history', () async {
      final auth = await wiredAuth();
      final nav = auth.navigation;

      final peer1 = _peer(_profile(_agent2, 'alfredagent2'));
      final peer2 = _peer(_profile(_agent1, 'alfredagent1'));

      await auth.setFocus(_agent1);
      await nav.openConversation(peer1);
      expect(auth.viewState.activePeer?.profileId, _agent2);

      final scopeAgent1 = testConversationScope(
        userId: _agent1,
        peerProfileId: auth.viewState.activePeer!.profileId,
        sessionEpoch: 1,
      );
      final chatAsAgent1 = MessagesController(
        scope: scopeAgent1,
        messageStore: testMessageStoreFor(scopeAgent1),
        userId: _agent1,
        peerProfileId: auth.viewState.activePeer!.profileId,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(chatAsAgent1);
      expect(chatAsAgent1.messages.length, 2);

      await auth.setFocus(_agent2);
      await nav.openConversation(peer2);
      expect(auth.viewState.activePeer?.profileId, _agent1);

      final scopeAgent2 = testConversationScope(
        userId: _agent2,
        peerProfileId: auth.viewState.activePeer!.profileId,
        sessionEpoch: 1,
      );
      final chatAsAgent2 = MessagesController(
        scope: scopeAgent2,
        messageStore: testMessageStoreFor(scopeAgent2),
        userId: _agent2,
        peerProfileId: auth.viewState.activePeer!.profileId,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(chatAsAgent2);
      expect(chatAsAgent2.messages.length, 2);

      await auth.setFocus(_agent1);
      expect(auth.viewState.activePeer?.profileId, _agent2);

      final scopeAgainAgent1 = testConversationScope(
        userId: _agent1,
        peerProfileId: auth.viewState.activePeer!.profileId,
        sessionEpoch: 1,
      );
      final chatAgainAgent1 = MessagesController(
        scope: scopeAgainAgent1,
        messageStore: testMessageStoreFor(scopeAgainAgent1),
        userId: _agent1,
        peerProfileId: auth.viewState.activePeer!.profileId,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(chatAgainAgent1);
      expect(chatAgainAgent1.messages.length, 2);

      chatAsAgent1.dispose();
      chatAsAgent2.dispose();
      chatAgainAgent1.dispose();
    });

    test('stale peer equal to focused account is not used for chat', () async {
      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: _agent2, username: 'alfredagent2'),
        ],
        focusUserId: _agent2,
      );
      final wiredManager = AccountManager(storage: storage)
        ..restoreSessionForTest = manager.restoreSessionForTest;
      final auth = await createWiredAuthController(manager: wiredManager);
      await auth.initialize();

      await auth.navigation.openConversation(
        _peer(_profile(_agent2, 'alfredagent2')),
      );

      expect(auth.viewState.activePeer, isNull);
    });
  });
}
