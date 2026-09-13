// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/messaging/conversation_message_store.dart';
import 'package:alfred_client/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

void main() {
  group('ConversationMessageStore', () {
    test('apply scartato se scope non commesso', () {
      final store = ConversationMessageStore();
      final scope = testConversationScope(
        userId: 'account-a',
        peerAddress: 'agent_b',
      );
      final applied = store.applyLoadedMessages(
        scope,
        [
          ChatMessage(
            id: '1',
            body: 'x',
            timeLabel: '12:00',
            isMine: true,
            senderId: 'account-a',
          ),
        ],
        hasMoreOlder: false,
      );
      expect(applied, isFalse);
      expect(store.snapshot.messages, isEmpty);
    });

    test('beginLoad azzera lista prima del fetch', () {
      final store = ConversationMessageStore();
      final scope = testConversationScope(
        userId: 'account-a',
        peerAddress: 'agent_b',
      );
      store.bindCommittedScope(scope);
      store.applyLoadedMessages(
        scope,
        [
          ChatMessage(
            id: '1',
            body: 'old',
            timeLabel: '12:00',
            isMine: true,
            senderId: 'account-a',
          ),
        ],
        hasMoreOlder: false,
      );
      store.beginLoad(scope);
      expect(store.snapshot.phase, ConversationLoadPhase.loading);
      expect(store.snapshot.messages, isEmpty);
    });

    test('bindCommittedScope diverso scarta snapshot precedente', () {
      final store = ConversationMessageStore();
      final scopeA = testConversationScope(
        userId: 'account-a',
        peerAddress: 'peer',
        loadSeq: 1,
      );
      final scopeB = testConversationScope(
        userId: 'account-b',
        peerAddress: 'peer',
        loadSeq: 2,
      );
      store.bindCommittedScope(scopeA);
      store.applyLoadedMessages(
        scopeA,
        [
          ChatMessage(
            id: '1',
            body: 'prova-out',
            timeLabel: '12:00',
            isMine: true,
            senderId: 'account-b',
          ),
        ],
        hasMoreOlder: false,
      );
      store.bindCommittedScope(scopeB);
      expect(store.snapshot.messages, isEmpty);
      expect(store.snapshotFor(scopeA).messages, isEmpty);
    });
  });
}
