// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/push_conversation_key.dart';
import '../../providers/auth_controller.dart';
import '../../utils/push_platform.dart';
import '../machines/notifications/notifications_effects.dart';

/// Effetti notifications → [AuthController] e [PushPlatform].
class AuthNotificationsEffects implements NotificationsEffects {
  AuthNotificationsEffects(this._auth);

  final AuthController _auth;

  @override
  Future<bool> forwardOpenFromPushTap({
    required String recipientUserId,
    required String peerAddress,
  }) {
    return _auth.openConversationAfterPushTap(
      recipientUserId: recipientUserId,
      peerAddress: peerAddress,
    );
  }

  @override
  void persistPendingOpenChat({
    required String recipientUserId,
    required String peerAddress,
  }) {
    PushPlatform.persistPendingOpenChat(
      PushConversationKey(
        recipientUserId: recipientUserId,
        peerAddress: peerAddress,
      ),
    );
  }

  @override
  void clearPendingOpenChat() {
    PushPlatform.clearPendingOpenChat();
  }
}
