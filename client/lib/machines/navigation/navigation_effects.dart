// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';

/// Effetti navigation → [AccountManager] (unico punto verso il dominio account).
abstract class NavigationEffects {
  Future<void> focusAccount(String accountUserId);

  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    required bool allowProfileFallback,
    int inboxRetryAttempts = 10,
    bool skipStaleClear = false,
  });

  /// Tap notifica push — PROM-PUSH-NOTIFY-030/036, SURF-NOTIFICATIONS-007.
  Future<bool> openConversationFromPushTap({
    required String accountUserId,
    required String peerProfileId,
  });

  void openPeerOnFocusedAccount(ChatPeer peer);

  void closeConversation();

  void openGroupChat();

  void backToGroupHome();

  void mergeActivePeerFromInbox(ChatPeer inboxRow);

  /// Account in focus con `profileKind == group`.
  bool get focusedAccountIsGroup;
}
