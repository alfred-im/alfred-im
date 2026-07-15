// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/push_conversation_key.dart';
import 'package:alfred_client/utils/push_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDeepLink', () {
    const conversation = PushConversationKey(
      ownerUserId: 'account-a',
      peerProfileId: 'peer-b',
    );

    test('tryParseFragment round-trips hash', () {
      expect(
        PushDeepLink.tryParseFragment('push-chat/account-a/peer-b'),
        conversation,
      );
    });

    test('hashFor encodes conversation', () {
      expect(
        PushDeepLink.hashFor(conversation),
        '#push-chat/account-a/peer-b',
      );
    });

    test('rejects malformed fragment', () {
      expect(PushDeepLink.tryParseFragment('push-chat/account-a'), isNull);
      expect(PushDeepLink.tryParseFragment('test1/chat'), isNull);
    });
  });
}
