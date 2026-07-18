// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum ConversationLoadState { loading, ready, sessionBlocked }

sealed class ConversationLoadEvent { const ConversationLoadEvent(); }
final class LoadMessages extends ConversationLoadEvent { const LoadMessages(); }
final class ReloadMessages extends ConversationLoadEvent { const ReloadMessages(); }
final class MessagesLoaded extends ConversationLoadEvent { const MessagesLoaded(); }
final class LoadFailed extends ConversationLoadEvent { const LoadFailed(); }
final class SessionExpired extends ConversationLoadEvent { const SessionExpired(); }

class ConversationLoadMachine {
  ConversationLoadState state = ConversationLoadState.loading;
  void send(ConversationLoadEvent event) {
    switch (event) {
      case LoadMessages(): case ReloadMessages(): state = ConversationLoadState.loading;
      case MessagesLoaded(): case LoadFailed(): state = ConversationLoadState.ready;
      case SessionExpired(): state = ConversationLoadState.sessionBlocked;
    }
  }
}
