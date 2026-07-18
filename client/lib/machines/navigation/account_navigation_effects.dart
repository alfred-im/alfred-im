// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../services/account_manager.dart';
import '../../services/account_session.dart';
import '../../utils/diagnostic_log.dart';
import 'navigation_effects.dart';

/// Implementazione effetti navigation — logica ex-[NavigationCoordinator].
class AccountNavigationEffects implements NavigationEffects {
  AccountNavigationEffects(this._manager);

  final AccountManager _manager;

  static const _defaultInboxRetryAttempts = 10;
  static const _pushInboxRetryAttempts = 12;
  static const _inboxRetryDelay = Duration(milliseconds: 100);

  @override
  Future<void> focusAccount(String accountUserId) async {
    await _manager.setFocus(accountUserId);
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
      return;
    }
    _manager.openConversation(peer);
    diagLog(
      'nav',
      'open_peer',
      data: {'accountUserId': focus, 'peerProfileId': peer.profileId},
    );
  }

  @override
  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    required bool allowProfileFallback,
    int inboxRetryAttempts = _defaultInboxRetryAttempts,
    bool skipStaleClear = false,
  }) async {
    diagLog(
      'nav',
      'open_on_account.start',
      data: {
        'accountUserId': accountUserId,
        'peerProfileId': peerProfileId,
        'focusBefore': _manager.focusUserId,
      },
    );

    if (accountUserId == peerProfileId) {
      diagLogFail(
        'nav',
        'open_on_account',
        'self_peer',
        data: {'accountUserId': accountUserId},
      );
      return false;
    }

    if (!skipStaleClear) {
      _manager.clearStaleConversationUnlessPeer(accountUserId, peerProfileId);
    }

    if (!await _ensureAccountFocused(accountUserId)) {
      return false;
    }

    final session = _manager.focusedSession;
    if (session == null || session.userId != accountUserId) {
      diagLogFail(
        'nav',
        'open_on_account',
        'wrong_session',
        data: {
          'expected': accountUserId,
          'actual': session?.userId,
        },
      );
      return false;
    }

    final peer = await _resolvePeer(
      session: session,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
      inboxRetryAttempts: inboxRetryAttempts,
      logSource: 'resolve_peer',
    );

    if (peer == null) {
      diagLogFail(
        'nav',
        'open_on_account',
        'peer_not_found',
        data: {'peerProfileId': peerProfileId},
      );
      return false;
    }

    _manager.openConversation(peer);
    diagLog(
      'nav',
      'open_on_account.ok',
      data: {'accountUserId': accountUserId, 'peerProfileId': peerProfileId},
    );
    return true;
  }

  @override
  Future<bool> openConversationFromPushTap({
    required String accountUserId,
    required String peerProfileId,
  }) {
    _manager.clearConversationForAccount(accountUserId);
    return openConversationOnAccount(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      allowProfileFallback: true,
      inboxRetryAttempts: _pushInboxRetryAttempts,
      skipStaleClear: true,
    );
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

    await _manager.setFocus(accountUserId);

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
