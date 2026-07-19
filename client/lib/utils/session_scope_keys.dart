// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/account_session.dart';

/// Chiave Provider/chat legata all'istanza [AccountSession] in RAM (non solo userId).
Key messagesSessionKey(AccountSession session, String peerProfileId) {
  return ValueKey(
    Object.hash(
      'peer-chat',
      session.userId,
      peerProfileId,
      identityHashCode(session),
    ),
  );
}

Key groupSessionKey(AccountSession session, String scope) {
  return ValueKey(Object.hash(scope, session.userId, identityHashCode(session)));
}
