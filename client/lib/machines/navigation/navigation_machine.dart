// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/conversation_scope.dart';
import '../../models/open_conversation_source.dart';
import '../../services/account_session.dart';
import 'navigation_effects.dart';

/// Stato shell navigation — `docs/model/uml/navigation/navigation-shell-state.puml`.
enum NavigationShellState {
  inboxVisible,
  chatOpen,
  groupShell,
}

sealed class NavigationEvent {
  const NavigationEvent();
}

final class SwitchToAccount extends NavigationEvent {
  const SwitchToAccount(this.accountUserId);
  final String accountUserId;
}

final class OpenPeerOnFocusedAccount extends NavigationEvent {
  const OpenPeerOnFocusedAccount(this.peer);
  final ChatPeer peer;
}

final class OpenConversationOnAccount extends NavigationEvent {
  const OpenConversationOnAccount({
    required this.accountUserId,
    required this.peerProfileId,
    this.source = OpenConversationSource.compose,
    this.allowProfileFallback = true,
  });

  final String accountUserId;
  final String peerProfileId;
  final OpenConversationSource source;
  final bool allowProfileFallback;
}

/// Tap notifica push — delega a [OpenConversationOnAccount] con source push.
final class OpenFromPushTap extends NavigationEvent {
  const OpenFromPushTap({
    required this.accountUserId,
    required this.peerProfileId,
  });

  final String accountUserId;
  final String peerProfileId;
}

/// Adapter shareable-link → OpenConversation source shareableLink.
final class OpenFromShareableLink extends NavigationEvent {
  const OpenFromShareableLink({
    required this.accountUserId,
    required this.peerProfileId,
  });

  final String accountUserId;
  final String peerProfileId;
}

/// Nuovo messaggio da compose — source compose.
final class OpenFromCompose extends NavigationEvent {
  const OpenFromCompose({
    required this.accountUserId,
    required this.peerProfileId,
    this.allowProfileFallback = true,
  });

  final String accountUserId;
  final String peerProfileId;
  final bool allowProfileFallback;
}

/// Back mobile / chiudi chat — inbox o group home.
final class CloseConversation extends NavigationEvent {
  const CloseConversation();
}

final class OpenGroupChat extends NavigationEvent {
  const OpenGroupChat();
}

final class BackToGroupHome extends NavigationEvent {
  const BackToGroupHome();
}

/// Aggiorna metadati peer attivo da riga inbox (preview, timestamp).
final class MergeActivePeerFromInbox extends NavigationEvent {
  const MergeActivePeerFromInbox(this.inboxRow);
  final ChatPeer inboxRow;
}

/// Macchina navigation — unico ingresso shell inbox/chat e proprietario di [ConversationScope].
class NavigationMachine {
  NavigationMachine(this._effects);

  final NavigationEffects _effects;

  NavigationShellState shellState = NavigationShellState.inboxVisible;
  ConversationScope? committedScope;

  void invalidateCommittedScope() {
    committedScope = null;
  }

  void commitScope(ConversationScope scope) {
    committedScope = scope;
  }

  bool isScopeCommitted(ConversationScope scope) =>
      isConversationReadyFor(
        ownerUserId: scope.ownerUserId,
        peerProfileId: scope.peerProfileId,
      );

  bool isConversationReady({
    required AccountSession session,
    required ChatPeer peer,
  }) {
    return isConversationReadyFor(
      ownerUserId: session.userId,
      peerProfileId: peer.profileId,
      sessionEpoch: session.epoch,
    );
  }

  bool isConversationReadyFor({
    required String ownerUserId,
    required String peerProfileId,
    int? sessionEpoch,
  }) {
    final committed = committedScope;
    if (committed == null) return false;
    if (committed.ownerUserId != ownerUserId ||
        committed.peerProfileId != peerProfileId) {
      return false;
    }
    if (sessionEpoch != null && committed.sessionEpoch != sessionEpoch) {
      committedScope = ConversationScope(
        ownerUserId: ownerUserId,
        peerProfileId: peerProfileId,
        sessionEpoch: sessionEpoch,
      );
    }
    return true;
  }

  void resetShellToAccountHome() {
    _effects.resetShellToAccountHome();
  }

  void syncShellFromCommittedScope() {
    _syncShellStateFromCommittedScope();
  }

  void _syncShellStateFromCommittedScope() {
    if (_effects.focusedAccountIsGroup) {
      shellState = NavigationShellState.groupShell;
      return;
    }
    shellState = committedScope != null
        ? NavigationShellState.chatOpen
        : NavigationShellState.inboxVisible;
  }

  Future<void> send(NavigationEvent event) async {
    switch (event) {
      case SwitchToAccount(:final accountUserId):
        invalidateCommittedScope();
        await _effects.focusAccount(accountUserId);
        resetShellToAccountHome();
        _syncShellStateFromCommittedScope();
      case OpenPeerOnFocusedAccount(:final peer):
        invalidateCommittedScope();
        _effects.openPeerOnFocusedAccount(peer);
        shellState = NavigationShellState.chatOpen;
      case OpenConversationOnAccount(
        :final accountUserId,
        :final peerProfileId,
        :final source,
        :final allowProfileFallback,
      ):
        await _openConversation(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          source: source,
          allowProfileFallback: allowProfileFallback,
        );
      case OpenFromPushTap(:final accountUserId, :final peerProfileId):
        await _openConversation(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          source: OpenConversationSource.push,
        );
      case OpenFromShareableLink(:final accountUserId, :final peerProfileId):
        await _openConversation(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          source: OpenConversationSource.shareableLink,
        );
      case OpenFromCompose(
        :final accountUserId,
        :final peerProfileId,
        :final allowProfileFallback,
      ):
        await _openConversation(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          source: OpenConversationSource.compose,
          allowProfileFallback: allowProfileFallback,
        );
      case CloseConversation():
        invalidateCommittedScope();
        _effects.closeConversation();
        shellState = _effects.focusedAccountIsGroup
            ? NavigationShellState.groupShell
            : NavigationShellState.inboxVisible;
      case OpenGroupChat():
        invalidateCommittedScope();
        _effects.openGroupChat();
        shellState = NavigationShellState.groupShell;
      case BackToGroupHome():
        _effects.backToGroupHome();
        shellState = NavigationShellState.groupShell;
      case MergeActivePeerFromInbox(:final inboxRow):
        _effects.mergeActivePeerFromInbox(inboxRow);
    }
  }

  Future<void> _openConversation({
    required String accountUserId,
    required String peerProfileId,
    required OpenConversationSource source,
    bool allowProfileFallback = true,
  }) async {
    invalidateCommittedScope();
    final ok = await _effects.openConversation(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      source: source,
      allowProfileFallback: allowProfileFallback,
    );
    shellState = ok
        ? NavigationShellState.chatOpen
        : _effects.focusedAccountIsGroup
            ? NavigationShellState.groupShell
            : NavigationShellState.inboxVisible;
  }
}
