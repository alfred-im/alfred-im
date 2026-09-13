// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/push_conversation_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushConversationKey', () {
    test('canonicalKey is recipient|peer', () {
      const key = PushConversationKey(
        recipientUserId: 'account-a',
        peerAddress: 'peer-b',
      );
      expect(key.canonicalKey, 'account-a|peer-b');
    });

    test('tryParseCanonical round-trips', () {
      const original = PushConversationKey(
        recipientUserId: 'account-a',
        peerAddress: 'peer-b',
      );
      expect(
        PushConversationKey.tryParseCanonical('account-a|peer-b'),
        original,
      );
    });

    test('tryParseCanonical rejects peer-only or malformed', () {
      expect(PushConversationKey.tryParseCanonical('peer-b'), isNull);
      expect(PushConversationKey.tryParseCanonical('a|b|c'), isNull);
      expect(PushConversationKey.tryParseCanonical('same|same'), isNull);
      expect(PushConversationKey.tryParseCanonical('|peer'), isNull);
    });

    test('tryFromPayload accepts camelCase and snake_case', () {
      expect(
        PushConversationKey.tryFromPayload({
          'recipientUserId': 'account-a',
          'peerAddress': 'peer-b',
        }),
        const PushConversationKey(
          recipientUserId: 'account-a',
          peerAddress: 'peer-b',
        ),
      );
      expect(
        PushConversationKey.tryFromPayload({
          'recipient_user_id': 'account-a',
          'peer_address': 'peer-b',
        }),
        const PushConversationKey(
          recipientUserId: 'account-a',
          peerAddress: 'peer-b',
        ),
      );
    });

    test('tryFromPayload rejects incomplete pair', () {
      expect(
        PushConversationKey.tryFromPayload({'peerAddress': 'peer-b'}),
        isNull,
      );
      expect(
        PushConversationKey.tryFromPayload({'recipientUserId': 'account-a'}),
        isNull,
      );
      expect(
        PushConversationKey.tryFromPayload({
          'recipientUserId': 'x',
          'peerAddress': 'x',
        }),
        isNull,
      );
    });

    test('notificationTag includes account and peer', () {
      const key = PushConversationKey(
        recipientUserId: 'account-a',
        peerAddress: 'peer-b',
      );
      expect(
        key.notificationTag('msg-uuid'),
        'account-a|peer-b|msg-uuid',
      );
      expect(key.notificationTag(''), 'account-a|peer-b');
    });

    test('distinct tags for same peer on different accounts', () {
      const keyA = PushConversationKey(
        recipientUserId: 'account-a',
        peerAddress: 'shared-peer',
      );
      const keyB = PushConversationKey(
        recipientUserId: 'account-b',
        peerAddress: 'shared-peer',
      );
      expect(
        keyA.notificationTag('same-logical-id'),
        isNot(keyB.notificationTag('same-logical-id')),
      );
    });

    test('outboundQueueKey matches canonicalKey', () {
      expect(
        PushConversationKey.outboundQueueKey(
          recipientUserId: 'account-a',
          peerAddress: 'peer-b',
        ),
        'account-a|peer-b',
      );
    });

    test('shouldSuppressInForeground matches account+peer only', () {
      const key = PushConversationKey(
        recipientUserId: 'account-b',
        peerAddress: 'peer-a',
      );
      expect(
        key.shouldSuppressInForeground(
          focusUserId: 'account-b',
          activePeerAddress: 'peer-a',
          appVisible: true,
        ),
        isTrue,
      );
      expect(
        key.shouldSuppressInForeground(
          focusUserId: 'account-a',
          activePeerAddress: 'peer-a',
          appVisible: true,
        ),
        isFalse,
      );
      expect(
        key.shouldSuppressInForeground(
          focusUserId: 'account-b',
          activePeerAddress: 'peer-other',
          appVisible: true,
        ),
        isFalse,
      );
      expect(
        key.shouldSuppressInForeground(
          focusUserId: 'account-b',
          activePeerAddress: 'peer-a',
          appVisible: false,
        ),
        isFalse,
      );
    });
  });
}
