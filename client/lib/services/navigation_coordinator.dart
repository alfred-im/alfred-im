// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../adapters/external_intent_adapter.dart';
import '../machines/multi-account/multi_account_adapters.dart';
import '../machines/navigation/account_navigation_effects.dart';
import '../machines/navigation/navigation_adapters.dart';
import '../machines/navigation/navigation_machine.dart';
import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../services/account_manager.dart';
import '../services/account_session.dart';

/// Fallback test: focus diretto su manager senza macchina.
class _ManagerFocusCommand implements AccountFocusCommand {
  _ManagerFocusCommand(this._manager);

  final AccountManager _manager;

  @override
  Future<void> focusAccount(String accountUserId) {
    return _manager.executeFocus(accountUserId);
  }
}

/// Unico ingresso per navigazione account → inbox → conversazione.
///
/// Tutti i cambi account (sidebar, push, link) passano da [NavigationMachine].
class NavigationCoordinator {
  NavigationCoordinator(
    this._manager, {
    AccountFocusCommand? focusCommand,
  }) {
    final command = focusCommand ?? _ManagerFocusCommand(_manager);
    _effects = AccountNavigationEffects(_manager, focusCommand: command);
    _machine = NavigationMachine(_effects);
    _effects.navigationMachine = _machine;
    adapters = NavigationAdapters(_machine);
    externalIntents = ExternalIntentAdapter(adapters);
  }

  final AccountManager _manager;
  late final AccountNavigationEffects _effects;
  late final NavigationMachine _machine;

  late final NavigationAdapters adapters;
  late final ExternalIntentAdapter externalIntents;

  /// Dopo ogni transazione navigation completata (scope commesso o invalidato).
  VoidCallback? onStateChanged;

  NavigationMachine get machine => _machine;

  ConversationScope? get committedScope => _machine.committedScope;

  bool get isChatShellOpen =>
      _machine.shellState == NavigationShellState.chatOpen;

  bool isConversationReady({
    required AccountSession session,
    required ChatPeer peer,
  }) {
    return _machine.isConversationReady(session: session, peer: peer);
  }

  void _notifyStateChanged() => onStateChanged?.call();

  void invalidateCommittedScope() {
    _machine.invalidateCommittedScope();
  }

  /// Bootstrap / reconnect: riallinea scope da view-state e shell.
  void restoreCommittedScopeAfterFocusSettled() {
    _machine.restoreCommittedScopeFromViewState();
    _machine.syncShellFromCommittedScope();
    _notifyStateChanged();
  }

  Future<void> switchToAccount(String accountUserId) async {
    await adapters.switchToAccount(accountUserId);
    _notifyStateChanged();
  }

  Future<void> openPeerOnFocusedAccount(ChatPeer peer) async {
    await adapters.openPeerOnFocusedAccount(peer);
    _notifyStateChanged();
  }

  Future<bool> ensureAccountFocused(String accountUserId) async {
    if (!_manager.hasOpenAccount(accountUserId)) {
      return false;
    }
    await adapters.switchToAccount(accountUserId);
    final session = _manager.focusedSession;
    final ok = _manager.focusUserId == accountUserId &&
        session != null &&
        session.userId == accountUserId;
    if (ok) _notifyStateChanged();
    return ok;
  }

  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    final ok = await adapters.openConversationOnAccount(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
    );
    _notifyStateChanged();
    return ok;
  }

  Future<bool> openFromShareableLink({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    final ok = await externalIntents.openFromShareableLink(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
    );
    _notifyStateChanged();
    return ok;
  }

  Future<bool> openFromCompose({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    final ok = await externalIntents.openFromCompose(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
    );
    _notifyStateChanged();
    return ok;
  }

  Future<void> closeConversation() async {
    await adapters.closeConversation();
    _notifyStateChanged();
  }

  Future<void> openGroupChat() async {
    await adapters.openGroupChat();
    _notifyStateChanged();
  }

  Future<void> backToGroupHome() async {
    await adapters.backToGroupHome();
    _notifyStateChanged();
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
