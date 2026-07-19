// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';

import '../support/fake_messaging_services.dart';

const _agent1 = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _agent2 = '0a81f785-173c-4f1c-b5df-3937086a2482';

ChatMessage _msg({
  required String id,
  required String body,
  required String senderId,
}) {
  return ChatMessage(
    id: id,
    body: body,
    timeLabel: '12:00',
    isMine: senderId == _agent1,
    senderId: senderId,
    createdAt: DateTime.utc(2026, 6, 29, 12),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessagesController multi-account chat', () {
    late FakeMessageService messageService;
    late FakeInboxService inboxService;
    late MessageMediaService mediaService;
    late OutboundMessageQueue outboundQueue;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      messageService = FakeMessageService(client);
      inboxService = FakeInboxService();
      mediaService = MessageMediaService(createTestSupabaseClient());
      outboundQueue = OutboundMessageQueue();
    });

    test('load fetches messages for account+peer, not peer alone', () async {
      messageService.messagesByConversation[conversationKey(
        userId: _agent1,
        peerProfileId: _agent2,
      )] = [
        _msg(id: 'm1', body: 'da agent1', senderId: _agent1),
      ];
      messageService.messagesByConversation[conversationKey(
        userId: _agent2,
        peerProfileId: _agent1,
      )] = [
        _msg(id: 'm2', body: 'da agent2', senderId: _agent2),
      ];

      final asAgent1 = MessagesController(
        scope: testConversationScope(userId: _agent1, peerProfileId: _agent2, sessionEpoch: 1),
        userId: _agent1,
        peerProfileId: _agent2,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: inboxService,
        outboundQueue: outboundQueue,
      );
      await waitForMessagesController(asAgent1);

      final asAgent2 = MessagesController(
        scope: testConversationScope(userId: _agent2, peerProfileId: _agent1, sessionEpoch: 1),
        userId: _agent2,
        peerProfileId: _agent1,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: inboxService,
        outboundQueue: OutboundMessageQueue(),
      );
      await waitForMessagesController(asAgent2);

      expect(asAgent1.messages.map((m) => m.body), ['da agent1']);
      expect(asAgent2.messages.map((m) => m.body), ['da agent2']);
      expect(asAgent1.error, isNull);
      expect(asAgent2.error, isNull);

      asAgent1.dispose();
      asAgent2.dispose();
    });

    test('self peer is not a valid conversation scope', () {
      expect(
        () => ConversationScope(
          ownerUserId: _agent1,
          peerProfileId: _agent1,
          sessionEpoch: 1,
        ),
        throwsAssertionError,
      );
    });

    test('load surfaces service errors instead of silent empty chat', () async {
      final broken = _BrokenMessageService();
      final controller = MessagesController(
        scope: testConversationScope(userId: _agent1, peerProfileId: _agent2, sessionEpoch: 1),
        userId: _agent1,
        peerProfileId: _agent2,
        messageService: broken,
        messageMediaService: mediaService,
        inboxService: inboxService,
        outboundQueue: OutboundMessageQueue(),
      );
      await waitForMessagesController(controller);

      expect(controller.messages, isEmpty);
      expect(controller.error, contains('RPC timeout simulato'));

      controller.dispose();
    });

    test('load reports expired session instead of silent empty chat', () async {
      final controller = MessagesController(
        scope: testConversationScope(userId: _agent1, peerProfileId: _agent2, sessionEpoch: 1),
        userId: _agent1,
        peerProfileId: _agent2,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: inboxService,
        outboundQueue: OutboundMessageQueue(),
        hasValidSession: () => false,
      );
      await waitForMessagesController(controller);

      expect(controller.messages, isEmpty);
      expect(controller.error, MessagesController.sessionExpiredMessage);

      controller.dispose();
    });

    test('realtime merges optimistic bubble by client_message_id', () async {
      const clientId = 'client-uuid-optimistic';
      const serverId = 'server-uuid-confirmed';

      final controller = MessagesController(
        scope: testConversationScope(userId: _agent1, peerProfileId: _agent2, sessionEpoch: 1),
        userId: _agent1,
        peerProfileId: _agent2,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: inboxService,
        outboundQueue: OutboundMessageQueue(),
      );
      await waitForMessagesController(controller);

      controller.messages = [
        ChatMessage(
          id: clientId,
          body: 'in invio',
          timeLabel: '12:00',
          isMine: true,
          status: MessageStatus.pending,
          createdAt: DateTime.utc(2026, 6, 29, 12),
          clientMessageId: clientId,
          senderId: _agent1,
        ),
      ];
      controller.notifyListeners();

      messageService.emitRealtimeMessage(
        userId: _agent1,
        peerProfileId: _agent2,
        message: ChatMessage(
          id: serverId,
          body: 'inviato',
          timeLabel: '',
          isMine: true,
          status: MessageStatus.sent,
          createdAt: DateTime.utc(2026, 6, 29, 12, 1),
          clientMessageId: clientId,
          senderId: _agent1,
        ),
      );

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.id, serverId);
      expect(controller.messages.single.body, 'inviato');
      expect(controller.messages.single.clientMessageId, clientId);

      controller.dispose();
    });
  });
}

class _BrokenMessageService extends FakeMessageService {
  _BrokenMessageService() : super(createTestSupabaseClient());
  @override
  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
    DateTime? beforeCreatedAt,
  }) {
    throw Exception('RPC timeout simulato');
  }
}
