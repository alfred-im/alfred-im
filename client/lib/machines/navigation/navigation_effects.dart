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
  });

  void openPeerOnFocusedAccount(ChatPeer peer);
}
