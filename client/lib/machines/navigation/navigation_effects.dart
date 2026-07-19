// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/open_conversation_source.dart';
import '../../services/account_manager.dart';

/// Effetti navigation → account manager + commit scope su [NavigationMachine].
abstract class NavigationEffects {
  Future<void> focusAccount(String accountUserId);

  /// Transazione unica OpenConversation — policy per [OpenConversationSource].
  Future<bool> openConversation({
    required String accountUserId,
    required String peerProfileId,
    required OpenConversationSource source,
    bool allowProfileFallback = true,
  });

  void openPeerOnFocusedAccount(ChatPeer peer);

  void closeConversation();

  void openGroupChat();

  void backToGroupHome();

  void mergeActivePeerFromInbox(ChatPeer inboxRow);

  /// Account in focus con `profileKind == group`.
  bool get focusedAccountIsGroup;

  /// Dopo focus settled: riallinea scope da view-state account in focus.
  void restoreCommittedScopeFromViewState(AccountManager manager);
}
