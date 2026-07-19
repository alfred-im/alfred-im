// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/conversation_scope.dart';
import '../../models/open_conversation_source.dart';
import '../../services/account_manager.dart';
import '../../services/account_session.dart';
import '../../utils/diagnostic_log.dart';
import '../multi-account/multi_account_adapters.dart';
import 'account_view_state_store.dart';
import 'navigation_effects.dart';
import 'navigation_machine.dart';

/// Implementazione effetti navigation — logica ex-[NavigationCoordinator].
class AccountNavigationEffects implements NavigationEffects {
  AccountNavigationEffects(
    this._manager, {
    required this._focusCommand,
  }) : _viewState = AccountViewStateStore(_manager);

  final AccountManager _manager;
  final AccountFocusCommand _focusCommand;
  final AccountViewStateStore _viewState;

  /// Impostato da [NavigationCoordinator] dopo creazione macchina.
  NavigationMachine? navigationMachine;

  static const _defaultInboxRetryAttempts = 10;
  static const _pushInboxRetryAttempts = 12;
  static const _inboxRetryDelay = Duration(milliseconds: 100);

  @override
  Future<void> focusAccount(String accountUserId) async {
    await _focusCommand.focusAccount(accountUserId);
  }

  @override
  bool get focusedAccountIsGroup =>
      _manager.focusedSession?.profile.isGroup ?? false;

  @override
  void restoreCommittedScopeFromViewState() {
    final userId = _manager.focusUserId;
    final session = _manager.focusedSession;
    final peer = userId == null ? null : _manager.viewStateFor(userId).activePeer;
    if (userId == null || session == null || peer == null) {
      navigationMachine?.invalidateCommittedScope();
      return;
    }
    if (peer.profileId == userId) {
      navigationMachine?.invalidateCommittedScope();
      return;
    }
    _commitScope(ConversationScope.fromSession(session, peer));
  }

  @override
  void closeConversation() {
    navigationMachine?.invalidateCommittedScope();
    if (focusedAccountIsGroup) {
      backToGroupHome();
      return;
    }
    _viewState.showInboxOnMobile();
  }

  @override
  void openGroupChat() {
    navigationMachine?.invalidateCommittedScope();
    _viewState.openGroupChat();
  }

  @override
  void backToGroupHome() {
    _viewState.backToGroupHome();
  }

  @override
  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    _viewState.mergeActivePeerFromInbox(inboxRow);
  }

  @override
  void openPeerOnFocusedAccount(ChatPeer peer) {
    final focus = _manager.focusUserId;
    if (focus == null || peer.profileId == focus) {
      diagLogFail(
        'nav',
        'open_peer',
        focus == null ? 'no_focus' : 'self_peer',
        data: {'peerProfileId': peer.profileId},
      );
      navigationMachine?.invalidateCommittedScope();
      return;
    }
    _viewState.openConversationOnFocusedAccount(peer);
    final session = _manager.focusedSession;
    if (session != null) {
      _commitScope(ConversationScope.fromSession(session, peer));
    }
    diagLog(
      'nav',
      'open_peer',
      data: {'accountUserId': focus, 'peerProfileId': peer.profileId},
    );
  }

  @override
  Future<bool> openConversation({
    required String accountUserId,
    required String peerProfileId,
    required OpenConversationSource source,
    bool allowProfileFallback = true,
  }) {
    return _openConversationImpl(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      source: source,
      allowProfileFallback: allowProfileFallback,
    );
  }

  Future<bool> _openConversationImpl({
    required String accountUserId,
    required String peerProfileId,
    required OpenConversationSource source,
    bool allowProfileFallback = true,
  }) async {
    diagLog(
      'nav',
      'open_conversation.start',
      data: {
        'accountUserId': accountUserId,
        'peerProfileId': peerProfileId,
        'source': source.name,
        'focusBefore': _manager.focusUserId,
      },
    );

    if (accountUserId == peerProfileId) {
      diagLogFail(
        'nav',
        'open_conversation',
        'self_peer',
        data: {'accountUserId': accountUserId},
      );
      return false;
    }

    switch (source) {
      case OpenConversationSource.push:
        _viewState.clearConversationForAccount(accountUserId);
      case OpenConversationSource.shareableLink:
      case OpenConversationSource.compose:
        _viewState.clearStaleConversationUnlessPeer(
          accountUserId,
          peerProfileId,
        );
      case OpenConversationSource.inbox:
        break;
    }

    if (!await _ensureAccountFocused(accountUserId)) {
      return false;
    }

    final session = _manager.focusedSession;
    if (session == null || session.userId != accountUserId) {
      diagLogFail(
        'nav',
        'open_conversation',
        'wrong_session',
        data: {
          'expected': accountUserId,
          'actual': session?.userId,
        },
      );
      return false;
    }

    final inboxRetryAttempts = source == OpenConversationSource.push
        ? _pushInboxRetryAttempts
        : _defaultInboxRetryAttempts;

    final peer = await _resolvePeer(
      session: session,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
      inboxRetryAttempts: inboxRetryAttempts,
      logSource: 'resolve_peer_${source.name}',
    );

    if (peer == null) {
      diagLogFail(
        'nav',
        'open_conversation',
        'peer_not_found',
        data: {'peerProfileId': peerProfileId},
      );
      return false;
    }

    _viewState.openConversationOnFocusedAccount(peer);
    _commitScope(ConversationScope.fromSession(session, peer));
    diagLog(
      'nav',
      'open_conversation.ok',
      data: {
        'accountUserId': accountUserId,
        'peerProfileId': peerProfileId,
        'source': source.name,
      },
    );
    return true;
  }

  void _commitScope(ConversationScope scope) {
    final session = _manager.focusedSession;
    if (session == null || !scope.matchesSession(session)) {
      navigationMachine?.invalidateCommittedScope();
      return;
    }
    navigationMachine?.commitScope(scope);
  }

  Future<bool> _ensureAccountFocused(String accountUserId) async {
    diagLog(
      'nav',
      'focus.start',
      data: {
        'accountUserId': accountUserId,
        'focusBefore': _manager.focusUserId,
      },
    );

    if (!_manager.hasOpenAccount(accountUserId)) {
      diagLogFail(
        'nav',
        'focus',
        'no_open_account',
        data: {'accountUserId': accountUserId},
      );
      return false;
    }

    await _focusCommand.focusAccount(accountUserId);

    final session = _manager.focusedSession;
    final ok = _manager.focusUserId == accountUserId &&
        session != null &&
        session.userId == accountUserId;

    if (ok) {
      diagLog('nav', 'focus.ok', data: {'accountUserId': accountUserId});
    } else {
      diagLogFail(
        'nav',
        'focus',
        'session_mismatch',
        data: {
          'accountUserId': accountUserId,
          'focusAfter': _manager.focusUserId,
          'sessionUserId': session?.userId,
        },
      );
    }
    return ok;
  }

  Future<ChatPeer?> resolvePeerInInboxForTest({
    required AccountSession session,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) {
    return _resolvePeer(
      session: session,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
      inboxRetryAttempts: _defaultInboxRetryAttempts,
      logSource: 'resolve_peer',
    );
  }

  Future<ChatPeer?> _resolvePeer({
    required AccountSession session,
    required String peerProfileId,
    required bool allowProfileFallback,
    required int inboxRetryAttempts,
    required String logSource,
  }) async {
    if (peerProfileId == session.userId) return null;

    for (var attempt = 0; attempt < inboxRetryAttempts; attempt++) {
      if (session.inboxController.isLoading) {
        await Future<void>.delayed(_inboxRetryDelay);
        continue;
      }

      await session.inboxController.load();
      final peer = session.inboxController.findByProfileId(peerProfileId);
      if (peer != null && peer.profileId != session.userId) {
        diagLog(
          'nav',
          logSource,
          data: {'source': 'inbox', 'attempt': attempt},
        );
        return peer;
      }

      if (attempt < inboxRetryAttempts - 1) {
        await Future<void>.delayed(_inboxRetryDelay);
      }
    }

    if (!allowProfileFallback) return null;

    try {
      final summary = await session.profileService.findById(peerProfileId);
      if (summary != null && summary.id != session.userId) {
        diagLog(
          'nav',
          logSource,
          data: {'source': 'profile_fallback'},
        );
        return ChatPeer(profile: summary);
      }
    } catch (e) {
      diagLogFail(
        'nav',
        logSource,
        'profile_lookup_error',
        data: {'error': e.runtimeType.toString()},
      );
    }

    return null;
  }
}
