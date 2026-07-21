// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/account_view_state.dart';
import '../../models/chat_peer.dart';
import '../../services/account_manager.dart';

/// Applica transizioni [AccountViewState] sullo storage per-account di
/// [AccountManager]. Unico punto di mutazione view-state (via navigation).
class AccountViewStateStore {
  AccountViewStateStore(this._manager);

  final AccountManager _manager;

  void openConversationOnFocusedAccount(ChatPeer peer) {
    final userId = _manager.focusUserId;
    if (userId == null || peer.profileId == userId) return;
    _manager.applyAccountViewState(userId, (view) => view.openChat(peer));
  }

  void clearConversationForAccount(String accountUserId) {
    _manager.applyAccountViewState(
      accountUserId,
      (view) => view.clearConversation(),
    );
  }

  /// Link / compose: azzera chat solo se il peer attivo è diverso dal target.
  void clearStaleConversationUnlessPeer(
    String accountUserId,
    String peerProfileId,
  ) {
    if (!_manager.hasOpenAccount(accountUserId)) return;
    final active = _manager.viewStateFor(accountUserId).activePeer?.profileId;
    if (active != null && active != peerProfileId) {
      clearConversationForAccount(accountUserId);
    }
  }

  void showInboxOnMobile() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    _manager.applyAccountViewState(
      userId,
      (view) => view.backToInboxOnMobile(),
    );
  }

  void openGroupChat() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    _manager.applyAccountViewState(userId, (view) => view.openGroupChat());
  }

  void backToGroupHome() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    _manager.applyAccountViewState(userId, (view) => view.backToGroupHome());
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    _manager.applyAccountViewState(
      userId,
      (view) => view.mergeActivePeer(inboxRow),
    );
  }

  /// Dopo cambio account: shell inbox (o home gruppo), senza commettere scope chat.
  void resetShellToAccountHome() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    if (_manager.focusedSession?.profile.isGroup ?? false) {
      _manager.applyAccountViewState(userId, (view) => view.backToGroupHome());
      return;
    }
    _manager.applyAccountViewState(userId, (view) => view.backToInboxOnMobile());
  }
}
