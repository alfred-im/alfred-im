// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Caricamento conversazione — `docs/model/uml/messaging/messaging-state.puml` (regione ConversationLoad).
enum ConversationLoadState { loading, ready, sessionBlocked }

sealed class ConversationLoadEvent { const ConversationLoadEvent(); }

/// Primo caricamento (adapter da `OpenConversation` navigation).
final class LoadMessages extends ConversationLoadEvent { const LoadMessages(); }

/// Dominio: `RefreshConversation`.
final class RefreshConversation extends ConversationLoadEvent {
  const RefreshConversation();
}

/// Dominio: evento `ConversationReady`.
final class ConversationReady extends ConversationLoadEvent {
  const ConversationReady();
}

/// Caricamento fallito — resta in `ready` con errore in coordinator (effetto).
final class LoadFailed extends ConversationLoadEvent { const LoadFailed(); }

/// Sessione non valida — regione `SessionBlocked`.
final class SessionExpired extends ConversationLoadEvent { const SessionExpired(); }

class ConversationLoadMachine {
  ConversationLoadState state = ConversationLoadState.loading;
  void send(ConversationLoadEvent event) {
    switch (event) {
      case LoadMessages():
      case RefreshConversation():
        state = ConversationLoadState.loading;
      case ConversationReady():
      case LoadFailed():
        state = ConversationLoadState.ready;
      case SessionExpired():
        state = ConversationLoadState.sessionBlocked;
    }
  }
}
