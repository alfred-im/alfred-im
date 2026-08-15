// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/conversation_scope.dart';
import '../services/account_session.dart';

Key navigationShellKey({
  required String? focusUserId,
  required ConversationScope? committedScope,
}) {
  return ValueKey(
    Object.hash(
      'navigation-shell',
      focusUserId,
      committedScope?.focusUserId,
      committedScope?.peerProfileId,
      committedScope?.sessionEpoch,
      committedScope?.loadSeq,
    ),
  );
}

/// Chiave Provider/chat legata a [ConversationScope].
Key conversationScopeKey(ConversationScope scope) => scope.providerKey;

Key groupSessionKey(AccountSession session, String scope) {
  return ValueKey(Object.hash(scope, session.userId, session.epoch));
}
