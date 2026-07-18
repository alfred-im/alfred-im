// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';

import '../support/fake_messaging_services.dart';

const _agent1 = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _agent2 = '0a81f785-173c-4f1c-b5df-3937086a2482';

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
    late NavigationCoordinator nav;
    late FakeMessageService messageService;
    late FakeInboxService inboxService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      nav = NavigationCoordinator(manager);
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
    });

    test('focus switch keeps per-account chat and loads correct history', () async {
      manager.seedTestAccount(_agent1);
      manager.seedTestAccount(_agent2);

      final peer1 = _peer(_profile(_agent2, 'alfredagent2'));
      final peer2 = _peer(_profile(_agent1, 'alfredagent1'));

      await manager.setFocus(_agent1);
      nav.openPeerOnFocusedAccount(peer1);
      expect(manager.viewState.activePeer?.profileId, _agent2);

      final chatAsAgent1 = MessagesController(
        userId: _agent1,
        peerProfileId: manager.viewState.activePeer!.profileId,
        messageService: messageService,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
      );
      await waitForMessagesController(chatAsAgent1);
      expect(chatAsAgent1.messages.length, 2);

      await manager.setFocus(_agent2);
      nav.openPeerOnFocusedAccount(peer2);
      expect(manager.viewState.activePeer?.profileId, _agent1);

      final chatAsAgent2 = MessagesController(
        userId: _agent2,
        peerProfileId: manager.viewState.activePeer!.profileId,
        messageService: messageService,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
      );
      await waitForMessagesController(chatAsAgent2);
      expect(chatAsAgent2.messages.length, 2);

      await manager.setFocus(_agent1);
      expect(manager.viewState.activePeer?.profileId, _agent2);

      final chatAgainAgent1 = MessagesController(
        userId: _agent1,
        peerProfileId: manager.viewState.activePeer!.profileId,
        messageService: messageService,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
      );
      await waitForMessagesController(chatAgainAgent1);
      expect(chatAgainAgent1.messages.length, 2);

      chatAsAgent1.dispose();
      chatAsAgent2.dispose();
      chatAgainAgent1.dispose();
    });

    test('stale peer equal to focused account is not used for chat', () async {
      manager.seedTestAccount(_agent2);
      await manager.setFocus(_agent2);

      // Simula stato corrotto: peer = sé stessi (bug dopo switch da altro account).
      nav.openPeerOnFocusedAccount(_peer(_profile(_agent2, 'alfredagent2')));

      expect(manager.viewState.activePeer, isNull);
    });
  });
}
