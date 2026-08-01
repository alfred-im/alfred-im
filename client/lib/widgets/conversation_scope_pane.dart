// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../groups/group_peer_author_enrichment.dart';
import '../providers/auth_controller.dart';
import '../providers/messages_controller.dart';
import '../services/account_session.dart';
import '../theme/alfred_colors.dart';
import '../utils/conversation_scope_guard.dart';
import '../utils/conversation_session_access.dart';
import '../utils/session_scope_keys.dart';
import '../widgets/chat_panel.dart';

/// Detail pane for a committed 1:1 or group DM conversation scope.
class ConversationScopePane extends StatelessWidget {
  const ConversationScopePane({
    super.key,
    required this.auth,
    required this.session,
    required this.showBackButton,
    this.onBack,
    required this.onMessagesChanged,
  });

  final AuthController auth;
  final AccountSession? session;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function() onMessagesChanged;

  Widget _ingressPanel(ChatPeer peer) {
    return ChatIngressPanel(
      peer: peer,
      showBackButton: showBackButton,
      onBack: onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final peer = auth.activePeer;
    if (peer == null) {
      return const EmptyChatPlaceholder();
    }

    final activeSession = session;
    if (activeSession == null) {
      return _ingressPanel(peer);
    }

    if (activeSession.userId != auth.userId) {
      return _ingressPanel(peer);
    }

    if (!auth.navigation.isConversationReady(
      session: activeSession,
      peer: peer,
    )) {
      return _ingressPanel(peer);
    }

    final scope = auth.navigation.committedScope;
    if (scope == null || !scope.matches(activeSession, peer)) {
      return _ingressPanel(peer);
    }

    return _ChatWithMessages(
      key: conversationScopeKey(scope),
      auth: auth,
      session: activeSession,
      peer: peer,
      scope: scope,
      showBackButton: showBackButton,
      onBack: onBack,
      onMessagesChanged: onMessagesChanged,
    );
  }
}

class _ChatWithMessages extends StatelessWidget {
  const _ChatWithMessages({
    super.key,
    required this.auth,
    required this.session,
    required this.peer,
    required this.scope,
    this.showBackButton = false,
    this.onBack,
    required this.onMessagesChanged,
  });

  final AuthController auth;
  final AccountSession session;
  final ChatPeer peer;
  final ConversationScope scope;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Future<void> Function() onMessagesChanged;

  bool _messagingSessionReady(AccountSession liveSession) {
    return isMessagingSessionReady(
      client: liveSession.client,
      ownerUserId: liveSession.userId,
      peerProfileId: peer.profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveSession = auth.focusedSession;
    final committed = auth.navigation.committedScope;
    if (liveSession == null ||
        committed == null ||
        !committed.isSameConversationAs(scope) ||
        liveSession.userId != scope.ownerUserId ||
        !_messagingSessionReady(liveSession) ||
        !auth.navigation.isConversationReady(
          session: liveSession,
          peer: peer,
        )) {
      return ChatIngressPanel(
        peer: peer,
        showBackButton: showBackButton,
        onBack: onBack,
      );
    }

    return ChangeNotifierProvider(
      key: conversationScopeKey(committed),
      create: (_) => MessagesController(
        scope: committed,
        userId: liveSession.userId,
        peerProfileId: peer.profileId,
        messageService: liveSession.messageService,
        messageMediaService: liveSession.messageMediaService,
        inboxService: liveSession.inboxService,
        profileService: liveSession.profileService,
        groupPeerAuthorEnrichment: peer.isGroup
            ? GroupPeerAuthorEnrichment(
                profileService: liveSession.profileService,
                userId: liveSession.userId,
              )
            : null,
        onMessagesChanged: onMessagesChanged,
        hasValidSession: () {
          final current = auth.focusedSession;
          final committedNow = auth.navigation.committedScope;
          if (current == null || committedNow == null) return false;
          if (!committedNow.isSameConversationAs(scope)) return false;
          auth.navigation.isConversationReady(session: current, peer: peer);
          return _messagingSessionReady(current);
        },
        resolveMessageMediaService: () {
          final current = auth.focusedSession;
          if (current == null) return liveSession.messageMediaService;
          return current.messageMediaService;
        },
        isScopeCommitted: () {
          final committedNow = auth.navigation.committedScope;
          final current = auth.focusedSession;
          if (committedNow == null || current == null) return false;
          return isMessagesScopeActive(
            scope: committedNow,
            committedScope: committedNow,
            peer: peer,
            liveSession: current,
            isConversationReady: (session, activePeer) =>
                auth.navigation.isConversationReady(
                  session: session,
                  peer: activePeer,
                ),
          );
        },
        messageStore: auth.navigation.messageStore,
      ),
      child: ChatPanel(
        peer: peer,
        showBackButton: showBackButton,
        onBack: onBack,
        showAuthorLabels: peer.isGroup,
      ),
    );
  }
}

class EmptyChatPlaceholder extends StatelessWidget {
  const EmptyChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.surface,
      child: Center(
        child: Text(
          'Seleziona una chat o scrivi a un indirizzo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AlfredColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
