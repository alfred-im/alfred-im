// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Sorgente di un comando [OpenConversation] — stessa transazione, policy diverse.
enum OpenConversationSource {
  /// Tap riga inbox o apertura peer su account già in focus.
  inbox,

  /// Tap notifica push — clear chat stale su account destinatario, retry inbox esteso.
  push,

  /// Fragment link condivisibile — clear stale se peer diverso, fallback profilo.
  shareableLink,

  /// Compose / nuovo messaggio da indirizzo.
  compose,
}
