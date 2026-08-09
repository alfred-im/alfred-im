// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_session.dart';

/// Costruisce scope da sessione viva + peer (solo test / harness).
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

/// Chiave Provider/chat legacy — include epoch sessione (non solo userId).
Key messagesSessionKey(AccountSession session, String peerProfileId) {
  return conversationScopeFor(session, peerProfileId).providerKey;
}
