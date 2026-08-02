// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_peer.dart';
import '../../models/conversation_scope.dart';
import '../../models/open_conversation_source.dart';
import '../../services/account_manager.dart';
import '../../services/account_session.dart';
import '../../services/session_authority.dart';
import '../../utils/diagnostic_log.dart';
import '../multi-account/multi_account_adapters.dart';
import 'account_view_state_store.dart';
import 'navigation_effects.dart';

/// Implementazione effetti navigation — logica ex-[NavigationCoordinator].
class AccountNavigationEffects implements NavigationEffects {
  AccountNavigationEffects(
    this._manager, {
    required this._focusCommand,
    required void Function() onInvalidateCommittedScope,
    required void Function(ConversationScope) onCommitScope,
    this._onIngressPrepComplete,
    SessionAuthority? sessionAuthority,
  })  : _authority = sessionAuthority ?? _manager.sessionAuthority,
        _invalidateCommittedScope = onInvalidateCommittedScope,
        _commitScopeCallback = onCommitScope;

  final AccountManager _manager;
  final SessionAuthority _authority;
  final AccountFocusCommand _focusCommand;
  final void Function() _invalidateCommittedScope;
  final void Function(ConversationScope) _commitScopeCallback;
  final VoidCallback? _onIngressPrepComplete;
  AccountViewStateStore get _viewState => _manager.viewStateStore;

  static const _defaultInboxRetryAttempts = 10;
  static const _pushInboxRetryAttempts = 12;
  static const _inboxRetryDelay = Duration(milliseconds: 100);

  int _ingressPrepGeneration = 0;

  @override
  Future<void> focusAccount(String accountUserId) async {
    await _focusCommand.focusAccount(accountUserId);
  }

  @override
  bool get focusedAccountIsGroup =>
      _manager.focusedSession?.profile.isGroup ?? false;

  @override
  void resetShellToAccountHome() {
    _viewState.resetShellToAccountHome();
  }

  @override
  void closeConversation() {
    if (focusedAccountIsGroup) {
      backToGroupHome();
      return;
    }
    _viewState.showInboxOnMobile();
  }

  @override
  void openGroupChat() {
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
  Future<bool> openPeerOnFocusedAccount(ChatPeer peer) async {
    final focus = _manager.focusUserId;
    if (focus == null || peer.profileId == focus) {
      diagLogFail(
        'nav',
        'open_peer',
        focus == null ? 'no_focus' : 'self_peer',
        data: {'peerProfileId': peer.profileId},
      );
      return false;
    }

    if (!_manager.hasOpenAccount(focus)) {
      diagLogFail(
        'nav',
        'open_peer',
        'no_open_account',
        data: {'accountUserId': focus},
      );
      return false;
    }

    _enterConversationUi(peer);
    unawaited(
      _prepareConversationAfterIngress(
        accountUserId: focus,
        peerProfileId: peer.profileId,
      ),
    );
    diagLog(
      'nav',
      'open_peer',
      data: {'accountUserId': focus, 'peerProfileId': peer.profileId},
    );
    return true;
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

    if (!_manager.hasOpenAccount(accountUserId)) {
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

    if (_manager.focusUserId != accountUserId) {
      await _focusCommand.focusAccount(accountUserId);
    }

    var session = _manager.focusedSession;
    if (session == null || session.userId != accountUserId) {
      if (!await _consolidateSessionForAccount(accountUserId)) {
        return false;
      }
      session = _manager.focusedSession;
    }
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

    final cachedPeer = session.inboxController.findByProfileId(peerProfileId);
    if (cachedPeer != null && cachedPeer.profileId != session.userId) {
      _enterConversationUi(cachedPeer);
      unawaited(
        _prepareConversationAfterIngress(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
        ),
      );
      diagLog(
        'nav',
        'open_conversation.ok',
        data: {
          'accountUserId': accountUserId,
          'peerProfileId': peerProfileId,
          'source': source.name,
          'ingress': 'cached_peer',
        },
      );
      return true;
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
      showInboxLoadingIndicator: false,
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

    _enterConversationUi(peer);
    unawaited(
      _prepareConversationAfterIngress(
        accountUserId: accountUserId,
        peerProfileId: peer.profileId,
      ),
    );
    diagLog(
      'nav',
      'open_conversation.ok',
      data: {
        'accountUserId': accountUserId,
        'peerProfileId': peerProfileId,
        'source': source.name,
        'ingress': 'resolved_peer',
      },
    );
    return true;
  }

  void _enterConversationUi(ChatPeer peer) {
    _viewState.openConversationOnFocusedAccount(peer);
    final session = _manager.focusedSession;
    if (session != null) {
      _commitScope(ConversationScope.fromSession(session, peer));
    }
  }

  Future<void> _prepareConversationAfterIngress({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    final generation = ++_ingressPrepGeneration;
    try {
      if (!await _consolidateSessionForAccount(accountUserId)) return;
      if (generation != _ingressPrepGeneration) return;
      if (_viewState.viewStateFor(accountUserId).activePeer?.profileId !=
          peerProfileId) {
        return;
      }

      final session = _manager.focusedSession;
      if (session == null || session.userId != accountUserId) return;

      var peer = session.inboxController.findByProfileId(peerProfileId);
      if (peer == null) {
        final summary = await session.profileService.findById(peerProfileId);
        if (summary == null || summary.id == session.userId) return;
        peer = ChatPeer(profile: summary);
      }

      if (generation != _ingressPrepGeneration) return;
      if (_viewState.viewStateFor(accountUserId).activePeer?.profileId !=
          peerProfileId) {
        return;
      }

      _commitScope(ConversationScope.fromSession(session, peer));
      _onIngressPrepComplete?.call();

      if (generation != _ingressPrepGeneration) return;
      await _manager.refreshFocusedInboxSilently();
    } catch (_) {
      diagLogFail(
        'nav',
        'ingress_prep',
        'failed',
        data: {'accountUserId': accountUserId, 'peerProfileId': peerProfileId},
      );
    }
  }

  void _commitScope(ConversationScope scope) {
    final session = _manager.focusedSession;
    if (session == null || !scope.matchesSession(session)) {
      _invalidateCommittedScope();
      return;
    }
    _commitScopeCallback(scope);
  }

  Future<bool> _consolidateSessionForAccount(String accountUserId) async {
    if (!_manager.hasOpenAccount(accountUserId)) {
      return false;
    }

    try {
      if (_manager.focusUserId != accountUserId) {
        await _focusCommand.focusAccount(accountUserId);
      }
      final ok = await _authority.ensureOwnerReady(accountUserId);
      if (!ok) {
        diagLogFail(
          'nav',
          'focus',
          'session_mismatch',
          data: {
            'accountUserId': accountUserId,
            'focusAfter': _manager.focusUserId,
            'sessionUserId': _manager.focusedSession?.userId,
          },
        );
      }
      return ok;
    } catch (_) {
      diagLogFail(
        'nav',
        'focus',
        'consolidate_failed',
        data: {'accountUserId': accountUserId},
      );
      return false;
    }
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
    bool showInboxLoadingIndicator = true,
  }) async {
    if (peerProfileId == session.userId) return null;

    for (var attempt = 0; attempt < inboxRetryAttempts; attempt++) {
      if (session.inboxController.isLoading) {
        await Future<void>.delayed(_inboxRetryDelay);
        continue;
      }

      await session.inboxController.load(
        showLoadingIndicator: showInboxLoadingIndicator,
      );
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
