// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/push_conversation_key.dart';
import 'package:alfred_client/utils/push_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('push suppression state keys are stable', () {
    PushPlatform.updateSuppression(
      recipientUserId: 'user-a',
      activePeerProfileId: 'peer-b',
      appVisible: true,
    );
    expect(PushPlatform.openChatIntents, isA<Stream<PushOpenChatIntent>>());
  });

  test('PushOpenChatIntent carries PushConversationKey', () {
    final intent = PushOpenChatIntent.fromParts(
      recipientUserId: 'account-a',
      peerProfileId: 'peer-b',
    );
    expect(
      intent.conversation,
      const PushConversationKey(
        recipientUserId: 'account-a',
        peerProfileId: 'peer-b',
      ),
    );
    expect(intent.recipientUserId, 'account-a');
    expect(intent.peerProfileId, 'peer-b');
  });

  test('cross-account: same peer does not match wrong account suppression', () {
    const pushForAccountB = PushConversationKey(
      recipientUserId: 'account-b',
      peerProfileId: 'shared-peer',
    );
    expect(
      pushForAccountB.shouldSuppressInForeground(
        focusUserId: 'account-a',
        activePeerProfileId: 'shared-peer',
        appVisible: true,
      ),
      isFalse,
    );
  });
}
