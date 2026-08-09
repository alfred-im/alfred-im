// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../machines/messaging/conversation_message_store.dart';
import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../services/account_session.dart';
import 'navigation_coordinator.dart';

/// Confine read + command navigation per la sessione UI (shell chat / inbox).
class NavigationSessionAccess {
  NavigationSessionAccess(this._coordinator);

  final NavigationCoordinator _coordinator;

  ConversationScope? get committedScope => _coordinator.committedScope;

  ConversationMessageStore get messageStore => _coordinator.messageStore;

  bool get isChatShellOpen => _coordinator.isChatShellOpen;

  bool isConversationReady({
    required AccountSession session,
    required ChatPeer peer,
  }) =>
      _coordinator.isConversationReady(session: session, peer: peer);

  Future<void> openConversation(ChatPeer peer) =>
      _coordinator.openPeerOnFocusedAccount(peer);

  Future<void> backToInboxOnMobile() => _coordinator.closeConversation();

  Future<void> openGroupChat() => _coordinator.openGroupChat();

  Future<void> backToGroupHome() => _coordinator.backToGroupHome();

  void mergeActivePeerFromInbox(ChatPeer inboxRow) =>
      _coordinator.adapters.mergeActivePeerFromInbox(inboxRow);
}
