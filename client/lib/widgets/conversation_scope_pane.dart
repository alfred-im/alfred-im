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

  @override
  Widget build(BuildContext context) {
    final peer = auth.activePeer;
    final activeSession = session;
    if (peer == null || activeSession == null) {
      return const EmptyChatPlaceholder();
    }

    if (activeSession.userId != auth.userId) {
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.navigation.isConversationReady(
      session: activeSession,
      peer: peer,
    )) {
      if (auth.navigation.committedScope == null) {
        return const EmptyChatPlaceholder();
      }
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final scope = auth.navigation.committedScope;
    if (scope == null || !scope.matches(activeSession, peer)) {
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
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

  bool _focusedSessionValid() {
    final live = auth.focusedSession;
    return live != null && live.userId == session.userId && live.hasValidJwt();
  }

  @override
  Widget build(BuildContext context) {
    final liveSession = auth.focusedSession;
    if (liveSession == null ||
        liveSession.userId != session.userId ||
        !scope.matches(liveSession, peer) ||
        !auth.navigation.isConversationReady(
          session: liveSession,
          peer: peer,
        )) {
      return const ColoredBox(
        color: AlfredColors.surface,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => MessagesController(
        scope: scope,
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
        hasValidSession: _focusedSessionValid,
        isScopeCommitted: () => isMessagesScopeActive(
          scope: scope,
          committedScope: auth.navigation.committedScope,
          peer: peer,
          liveSession: auth.focusedSession,
          isConversationReady: (session, activePeer) =>
              auth.navigation.isConversationReady(session: session, peer: activePeer),
        ),
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
