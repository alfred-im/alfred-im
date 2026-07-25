// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';

Key navigationShellKey({
  required String? focusUserId,
  required ConversationScope? committedScope,
}) {
  return ValueKey(
    Object.hash(
      'navigation-shell',
      focusUserId,
      committedScope?.ownerUserId,
      committedScope?.peerProfileId,
      committedScope?.sessionEpoch,
      committedScope?.loadSeq,
    ),
  );
}

/// Chiave Provider/chat legata a [ConversationScope].
Key conversationScopeKey(ConversationScope scope) => scope.providerKey;

/// Costruisce scope da sessione viva + peer.
ConversationScope conversationScopeFor(
  AccountSession session,
  String peerProfileId,
) {
  return ConversationScope.fromSession(
    session,
    ChatPeer(
      profile: ProfileSummary(
        id: peerProfileId,
        displayName: peerProfileId,
      ),
    ),
  );
}

/// Chiave Provider/chat — include epoch sessione (non solo userId).
Key messagesSessionKey(AccountSession session, String peerProfileId) {
  return conversationScopeFor(session, peerProfileId).providerKey;
}

Key groupSessionKey(AccountSession session, String scope) {
  return ValueKey(Object.hash(scope, session.userId, session.epoch));
}
