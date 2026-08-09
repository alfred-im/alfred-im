// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/messaging/conversation_message_store.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

/// INV-R4 — scenario prova-out: mailbox test4→test2 non visibile su test1→test2.
const _provaOut = 'prova-out';
const _test1Id = 'account-test1';
const _test4Id = 'account-test4';
const _test2Id = 'account-test2';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('INV-R4 archivio condiviso: dopo switch account niente prova-out', () async {
    final client4 = createTestSupabaseClient();
    final client1 = createTestSupabaseClient();
    final service4 = DelayedFakeMessageService(
      client4,
      fetchDelay: const Duration(milliseconds: 60),
    );
    final service1 = DelayedFakeMessageService(
      client1,
      fetchDelay: const Duration(milliseconds: 60),
    );

    service4.messagesByConversation[conversationKey(
      userId: _test4Id,
      peerProfileId: _test2Id,
    )] = [
      ChatMessage(
        id: 't4-poison',
        body: _provaOut,
        timeLabel: '12:00',
        isMine: true,
        senderId: _test4Id,
        createdAt: DateTime.utc(2026, 7, 15, 20, 49),
      ),
    ];
    service1.messagesByConversation[conversationKey(
      userId: _test1Id,
      peerProfileId: _test2Id,
    )] = [
      ChatMessage(
        id: 't1-1',
        body: 'vai!',
        timeLabel: '12:00',
        isMine: true,
        senderId: _test1Id,
        createdAt: DateTime.utc(2026, 7, 15, 12),
      ),
    ];

    final store = ConversationMessageStore();
    final scope4 = testConversationScope(
      userId: _test4Id,
      peerProfileId: _test2Id,
      loadSeq: 1,
    );
    store.bindCommittedScope(scope4);

    final controller4 = MessagesController(
      scope: scope4,
      messageStore: store,
      userId: _test4Id,
      peerProfileId: _test2Id,
      peerMessages: service4.peerMessages,
      messageMediaService: MessageMediaService(client4),
      inboxService: FakeInboxService(),
      isScopeCommitted: () => true,
    );
    await waitForMessagesController(controller4);
    expect(controller4.messages.map((m) => m.body), contains(_provaOut));
    controller4.dispose();

    final scope1 = testConversationScope(
      userId: _test1Id,
      peerProfileId: _test2Id,
      loadSeq: 2,
    );
    store.bindCommittedScope(scope1);

    final controller1 = MessagesController(
      scope: scope1,
      messageStore: store,
      userId: _test1Id,
      peerProfileId: _test2Id,
      peerMessages: service1.peerMessages,
      messageMediaService: MessageMediaService(client1),
      inboxService: FakeInboxService(),
      isScopeCommitted: () => true,
    );
    await waitForMessagesController(controller1);

    expect(controller1.messages.map((m) => m.body), isNot(contains(_provaOut)));
    expect(controller1.messages.map((m) => m.body), contains('vai!'));
    controller1.dispose();
  });
}
