// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../services/account_manager.dart';

/// Applica transizioni [AccountViewState] sullo storage per-account.
/// Unico punto di mutazione view-state (via navigation).
class AccountViewStateStore {
  AccountViewStateStore(this._manager);

  final AccountManager _manager;
  final Map<String, AccountViewState> _viewsByAccount = {};

  AccountViewState viewStateFor(String? userId) {
    if (userId == null) return const AccountViewState();
    return _sanitizeView(userId, _storedViewFor(userId));
  }

  void apply(
    String accountUserId,
    AccountViewState Function(AccountViewState current) transform,
  ) {
    if (!_manager.hasOpenAccount(accountUserId)) return;
    _setViewFor(accountUserId, transform(_storedViewFor(accountUserId)));
  }

  void clearForAccount(String userId) {
    _viewsByAccount.remove(userId);
  }

  void clearAll() {
    _viewsByAccount.clear();
  }

  void openConversationOnFocusedAccount(ChatPeer peer) {
    final userId = _manager.focusUserId;
    if (userId == null || peer.profileId == userId) return;
    apply(userId, (view) => view.openChat(peer));
  }

  void clearConversationForAccount(String accountUserId) {
    apply(accountUserId, (view) => view.clearConversation());
  }

  /// Link / compose: azzera chat solo se il peer attivo è diverso dal target.
  void clearStaleConversationUnlessPeer(
    String accountUserId,
    String peerProfileId,
  ) {
    if (!_manager.hasOpenAccount(accountUserId)) return;
    final active = viewStateFor(accountUserId).activePeer?.profileId;
    if (active != null && active != peerProfileId) {
      clearConversationForAccount(accountUserId);
    }
  }

  void showInboxOnMobile() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    apply(userId, (view) => view.backToInboxOnMobile());
  }

  void openGroupChat() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    apply(userId, (view) => view.openGroupChat());
  }

  void backToGroupHome() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    apply(userId, (view) => view.backToGroupHome());
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    apply(userId, (view) => view.mergeActivePeer(inboxRow));
  }

  void patchActivePeer(String accountUserId, ChatPeer peer) {
    if (!_manager.hasOpenAccount(accountUserId)) return;
    apply(accountUserId, (view) => view.patchActivePeer(peer));
  }

  /// Dopo cambio account: shell inbox (o home gruppo), senza commettere scope chat.
  void resetShellToAccountHome() {
    final userId = _manager.focusUserId;
    if (userId == null) return;
    if (_manager.focusedSession?.profile.isGroup ?? false) {
      apply(userId, (view) => view.backToGroupHome());
      return;
    }
    apply(userId, (view) => view.backToInboxOnMobile());
  }

  AccountViewState _storedViewFor(String userId) =>
      _viewsByAccount[userId] ?? const AccountViewState();

  AccountViewState _sanitizeView(String userId, AccountViewState view) =>
      view.sanitizedForAccount(userId);

  void _setViewFor(String userId, AccountViewState view) {
    _viewsByAccount[userId] = _sanitizeView(userId, view);
  }
}
