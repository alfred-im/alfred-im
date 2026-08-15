// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../models/push_conversation_key.dart';

/// Web Push platform hooks — stub (non-web / test).
class PushPlatform {
  const PushPlatform._();

  static bool get isPushSupported => false;

  static String? get notificationPermission => null;

  static Future<String> getOrCreateDeviceId() async =>
      '00000000-0000-4000-8000-000000000000';

  static Future<PushSubscriptionKeys?> ensureSubscription({
    required String vapidPublicKey,
  }) async =>
      null;

  static void updateSuppression({
    required String? recipientUserId,
    required String? activePeerProfileId,
    required bool appVisible,
  }) {}

  static Stream<PushOpenChatIntent> get openChatIntents =>
      const Stream<PushOpenChatIntent>.empty();

  static void persistPendingOpenChat(PushConversationKey conversation) {}

  static PushOpenChatIntent? readPendingOpenChat() => null;

  static void clearPendingOpenChat() {}

  static void tryDrainPendingOpenChat() {}

  static void ensureMessageHook() {}

  static Future<void> unregisterServiceWorkerSubscription() async {}
}

class PushSubscriptionKeys {
  const PushSubscriptionKeys({
    required this.endpoint,
    required this.p256dhKey,
    required this.authKey,
  });

  final String endpoint;
  final String p256dhKey;
  final String authKey;
}

class PushOpenChatIntent {
  const PushOpenChatIntent(this.conversation);

  factory PushOpenChatIntent.fromParts({
    required String recipientUserId,
    required String peerProfileId,
  }) {
    return PushOpenChatIntent(
      PushConversationKey(
        recipientUserId: recipientUserId,
        peerProfileId: peerProfileId,
      ),
    );
  }

  final PushConversationKey conversation;

  String get recipientUserId => conversation.recipientUserId;

  String get peerProfileId => conversation.peerProfileId;
}
