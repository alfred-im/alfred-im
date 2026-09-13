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
      activePeerAddress: 'peer-b',
      appVisible: true,
    );
    expect(PushPlatform.openChatIntents, isA<Stream<PushOpenChatIntent>>());
  });

  test('PushOpenChatIntent carries PushConversationKey', () {
    final intent = PushOpenChatIntent.fromParts(
      recipientUserId: 'account-a',
      peerAddress: 'peer-b',
    );
    expect(
      intent.conversation,
      const PushConversationKey(
        recipientUserId: 'account-a',
        peerAddress: 'peer-b',
      ),
    );
    expect(intent.recipientUserId, 'account-a');
    expect(intent.peerAddress, 'peer-b');
  });

  test('cross-account: same peer does not match wrong account suppression', () {
    const pushForAccountB = PushConversationKey(
      recipientUserId: 'account-b',
      peerAddress: 'shared-peer',
    );
    expect(
      pushForAccountB.shouldSuppressInForeground(
        focusUserId: 'account-a',
        activePeerAddress: 'shared-peer',
        appVisible: true,
      ),
      isFalse,
    );
  });
}
