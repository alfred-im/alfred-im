// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/services/account_session.dart';

import 'fake_messaging_services.dart';

ConversationScope conversationScopeFor(
  AccountSession session,
  String peerAddress,
) =>
    ConversationScope.fromSession(session, testChatPeer(peerAddress));

Key messagesSessionKey(AccountSession session, String peerAddress) =>
    conversationScopeFor(session, peerAddress).providerKey;
