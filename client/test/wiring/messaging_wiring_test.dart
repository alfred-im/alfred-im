// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/message_media_service.dart';

import '../support/fake_messaging_services.dart';

const _userId = 'user-a';
const _peerId = 'peer-b';

/// Wiring: MessagesController → MessagingCoordinator → _LiveMessagingEffects
/// (effects live). Fake solo su MessageService (confine RPC).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('messaging wiring', () {
    late FakeMessageService messageService;
    late FakeInboxService inboxService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      messageService = FakeMessageService(client);
      inboxService = FakeInboxService();
    });

    test('send fallisce se la sessione diventa invalida dopo il load', () async {
      var sessionValid = true;
      final scope = testConversationScope(
        userId: _userId,
        peerProfileId: _peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: _userId,
        peerProfileId: _peerId,
        messageService: messageService,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
        hasValidSession: () => sessionValid,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);
      expect(controller.error, isNull);

      sessionValid = false;
      await controller.send('dopo invalidazione');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      controller.dispose();
    });

    test('sendText attraversa coordinator ed effects live', () async {
      final scope = testConversationScope(
        userId: _userId,
        peerProfileId: _peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: _userId,
        peerProfileId: _peerId,
        messageService: messageService,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: inboxService,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      expect(controller.isSending, isFalse);

      await controller.send('ciao wiring');

      expect(controller.isSending, isFalse);
      expect(controller.messages.length, greaterThanOrEqualTo(1));
      expect(controller.messages.last.body, 'ciao wiring');
      expect(messageService.sentBodies, contains('ciao wiring'));
    });

    test('queue key nel controller combina userId e peerProfileId', () {
      final key = MessagesController.outboundQueueKey(
        userId: _userId,
        peerProfileId: _peerId,
      );
      expect(key, '$_userId|$_peerId');
    });
  });
}
