// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/conversation_scope.dart';
import '../../models/open_conversation_source.dart';
import '../../services/account_session.dart';
import '../../utils/diagnostic_log.dart';
import '../messaging/conversation_message_store.dart';
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
  NavigationMachine(
    this._effects, {
    ConversationMessageStore? messageStore,
  }) : _messageStore = messageStore ?? ConversationMessageStore();

  final NavigationEffects _effects;
  final ConversationMessageStore _messageStore;

  ConversationMessageStore get messageStore => _messageStore;

  NavigationShellState shellState = NavigationShellState.inboxVisible;
  ConversationScope? committedScope;
  int _loadSeq = 0;

  void invalidateCommittedScope() {
    _loadSeq++;
    final previous = committedScope;
    committedScope = null;
    _messageStore.bindCommittedScope(null);
    DiagnosticHub.instance.emit(
      DiagnosticFlows.nav,
      'scope.invalidate',
      data: {
        'loadSeq': _loadSeq,
        'previousOwner': previous?.ownerUserId,
        'previousPeer': previous?.peerProfileId,
      },
    );
  }

  void commitScope(ConversationScope scope) {
    committedScope = scope.copyWith(loadSeq: _loadSeq);
    _messageStore.bindCommittedScope(committedScope);
    DiagnosticHub.instance.emit(
      DiagnosticFlows.nav,
      'scope.commit',
      data: {
        'ownerUserId': scope.ownerUserId,
        'peerProfileId': scope.peerProfileId,
        'sessionEpoch': scope.sessionEpoch,
        'loadSeq': _loadSeq,
      },
    );
  }

  /// Sessione ricreata (stesso account + peer): aggiorna epoch e invalida lista.
  bool reconcileSessionEpoch(AccountSession session) {
    final committed = committedScope;
    if (committed == null) return false;
    if (committed.ownerUserId != session.userId) return false;
    if (committed.sessionEpoch == session.epoch) return true;
    _loadSeq++;
    committedScope = committed.copyWith(
      sessionEpoch: session.epoch,
      loadSeq: _loadSeq,
    );
    _messageStore.bindCommittedScope(committedScope);
    DiagnosticHub.instance.emit(
      DiagnosticFlows.nav,
      'scope.epoch_reconcile',
      data: {
        'ownerUserId': session.userId,
        'previousEpoch': committed.sessionEpoch,
        'newEpoch': session.epoch,
        'loadSeq': _loadSeq,
      },
    );
    return true;
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
      return false;
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
        final peerOk = await _effects.openPeerOnFocusedAccount(peer);
        shellState = peerOk
            ? NavigationShellState.chatOpen
            : _effects.focusedAccountIsGroup
                ? NavigationShellState.groupShell
                : NavigationShellState.inboxVisible;
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
