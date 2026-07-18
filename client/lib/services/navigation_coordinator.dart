// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../machines/navigation/account_navigation_effects.dart';
import '../machines/navigation/navigation_adapters.dart';
import '../machines/navigation/navigation_machine.dart';
import '../models/chat_peer.dart';
import 'account_manager.dart';
import 'account_session.dart';

/// Unico ingresso per navigazione account → inbox → conversazione.
///
/// Implementazione: [NavigationMachine] + [AccountNavigationEffects].
/// Sidebar, tap inbox, push, link condivisibili passano da qui (via [AuthController]).
class NavigationCoordinator {
  NavigationCoordinator(this._manager) {
    _effects = AccountNavigationEffects(_manager);
    _machine = NavigationMachine(_effects);
    adapters = NavigationAdapters(_machine);
  }

  final AccountManager _manager;
  late final AccountNavigationEffects _effects;
  late final NavigationMachine _machine;

  late final NavigationAdapters adapters;

  NavigationMachine get machine => _machine;

  Future<void> switchToAccount(String accountUserId) {
    return adapters.switchToAccount(accountUserId);
  }

  void openPeerOnFocusedAccount(ChatPeer peer) {
    adapters.openPeerOnFocusedAccount(peer);
  }

  Future<bool> ensureAccountFocused(String accountUserId) async {
    if (!_manager.hasOpenAccount(accountUserId)) {
      return false;
    }
    await adapters.switchToAccount(accountUserId);
    final session = _manager.focusedSession;
    return _manager.focusUserId == accountUserId &&
        session != null &&
        session.userId == accountUserId;
  }

  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) {
    return adapters.openConversationOnAccount(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
    );
  }

  @visibleForTesting
  Future<ChatPeer?> resolvePeerInInboxForTest({
    required AccountSession session,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) {
    return _effects.resolvePeerInInboxForTest(
      session: session,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
    );
  }
}
