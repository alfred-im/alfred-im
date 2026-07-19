// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../adapters/external_intent_adapter.dart';
import '../machines/multi-account/multi_account_adapters.dart';
import '../machines/navigation/account_navigation_effects.dart';
import '../machines/navigation/navigation_adapters.dart';
import '../machines/navigation/navigation_machine.dart';
import '../machines/navigation/navigation_scope_host.dart';
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
/// Implementazione: [NavigationMachine] + [AccountNavigationEffects].
/// Sidebar, tap inbox, push, link condivisibili passano da qui (via [AuthController]).
class NavigationCoordinator implements NavigationScopeHost {
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

  NavigationMachine get machine => _machine;

  ConversationScope? get committedScope => _machine.committedScope;

  bool isConversationReady({
    required AccountSession session,
    required ChatPeer peer,
  }) {
    return _machine.isConversationReady(session: session, peer: peer);
  }

  @override
  void invalidateCommittedScope() {
    _machine.invalidateCommittedScope();
  }

  @override
  void restoreCommittedScopeAfterFocusSettled() {
    _machine.restoreCommittedScopeFromViewState(_manager);
  }

  @override
  bool get isOpenConversationInFlight => _effects.isOpenConversationInFlight;

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

  Future<bool> openFromShareableLink({
    required String accountUserId,
    required String peerProfileId,
  }) {
    return externalIntents.openFromShareableLink(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
    );
  }

  Future<bool> openFromCompose({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) {
    return externalIntents.openFromCompose(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
      allowProfileFallback: allowProfileFallback,
    );
  }

  Future<void> closeConversation() {
    return adapters.closeConversation();
  }

  Future<void> openGroupChat() {
    return adapters.openGroupChat();
  }

  Future<void> backToGroupHome() {
    return adapters.backToGroupHome();
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
