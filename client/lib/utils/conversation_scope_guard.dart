// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../services/account_session.dart';

/// True se [scope] (congelato nel [MessagesController]) è ancora l'ambito attivo.
///
/// INV-MSG-1: owner+peer del controller devono coincidere con la sessione live e
/// con [isConversationReady]. Non usare [ConversationScope.matches] sullo scope
/// congelato: l'epoch in RAM può avanzare prima del rebuild UI dopo switch account.
bool isMessagesScopeActive({
  required ConversationScope scope,
  required ChatPeer peer,
  required AccountSession? liveSession,
  required bool Function(AccountSession session, ChatPeer peer)
      isConversationReady,
}) {
  if (liveSession == null) return false;
  if (liveSession.userId != scope.ownerUserId) return false;
  if (peer.profileId != scope.peerProfileId) return false;
  return isConversationReady(liveSession, peer);
}
