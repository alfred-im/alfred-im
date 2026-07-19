// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/utils/conversation_scope_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

/// PROM-CONVERSATION-SCOPE-006 — contratto guard messaging
///
/// INV-MSG-1: fetch del controller (O,P) non applica messaggi se la sessione
///            live non corrisponde allo scope congelato del controller.
const _poisonBody = 'VELENO_MAILBOX_A_VERSO_B';
const _accountA = 'account-a';
const _accountB = 'account-b';

ProfileSummary _profile(String id) => ProfileSummary(
      id: id,
      username: id,
      displayName: id,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('INV-MSG messaging scope guard', () {
    test('INV-MSG-1 guard produzione blocca fetch controller fuori ambito', () async {
      final client = createTestSupabaseClient();
      final service = DelayedFakeMessageService(
        client,
        fetchDelay: const Duration(milliseconds: 80),
      );
      service.messagesByConversation[conversationKey(
        userId: _accountA,
        peerProfileId: _accountB,
      )] = [
        ChatMessage(
          id: 'poison-1',
          body: _poisonBody,
          timeLabel: '12:00',
          isMine: true,
          senderId: _accountA,
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
      ];

      final scopeAtoB = testConversationScope(
        userId: _accountA,
        peerProfileId: _accountB,
        sessionEpoch: 1,
      );
      final peerB = ChatPeer(profile: _profile(_accountB));

      final controller = MessagesController(
        scope: scopeAtoB,
        userId: _accountA,
        peerProfileId: _accountB,
        messageService: service,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        isScopeCommitted: () => isMessagesScopeActive(
          scope: scopeAtoB,
          peer: peerB,
          liveSession: null,
          isConversationReady: (_, _) => true,
        ),
      );

      await waitForMessagesController(controller);
      expect(controller.messages, isEmpty);
      controller.dispose();
    });

    test('INV-MSG-1 guard globale-only lascerebbe passare il veleno (regressione)', () async {
      final client = createTestSupabaseClient();
      final service = DelayedFakeMessageService(
        client,
        fetchDelay: const Duration(milliseconds: 80),
      );
      service.messagesByConversation[conversationKey(
        userId: _accountA,
        peerProfileId: _accountB,
      )] = [
        ChatMessage(
          id: 'poison-1',
          body: _poisonBody,
          timeLabel: '12:00',
          isMine: true,
          senderId: _accountA,
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
      ];

      final scopeAtoB = testConversationScope(
        userId: _accountA,
        peerProfileId: _accountB,
        sessionEpoch: 1,
      );

      final controller = MessagesController(
        scope: scopeAtoB,
        userId: _accountA,
        peerProfileId: _accountB,
        messageService: service,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        isScopeCommitted: () => true,
      );

      await waitForMessagesController(controller);
      expect(controller.messages.map((m) => m.body), contains(_poisonBody));
      controller.dispose();
    });

    test('epoch stale su scope congelato non blocca se conversation ready', () async {
      final client = createTestSupabaseClient();
      final service = DelayedFakeMessageService(
        client,
        fetchDelay: const Duration(milliseconds: 80),
      );
      service.messagesByConversation[conversationKey(
        userId: _accountA,
        peerProfileId: _accountB,
      )] = [
        ChatMessage(
          id: 'msg-1',
          body: 'ciao inbox-chat parity',
          timeLabel: '12:00',
          isMine: false,
          senderId: _accountB,
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
      ];

      final staleScope = testConversationScope(
        userId: _accountA,
        peerProfileId: _accountB,
        sessionEpoch: 1,
      );
      final peerB = ChatPeer(profile: _profile(_accountB));
      final liveSession = await AccountSession.createForTest(
        profile: _profile(_accountA),
        client: client,
        messageService: service,
      );

      final controller = MessagesController(
        scope: staleScope,
        userId: _accountA,
        peerProfileId: _accountB,
        messageService: service,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        isScopeCommitted: () => isMessagesScopeActive(
          scope: staleScope,
          peer: peerB,
          liveSession: liveSession,
          isConversationReady: (_, _) => true,
        ),
      );

      await waitForMessagesController(controller);
      expect(
        controller.messages.map((m) => m.body),
        contains('ciao inbox-chat parity'),
      );
      controller.dispose();
    });
  });
}
