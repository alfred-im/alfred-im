// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/external_intent_adapter.dart';
import '../coordinators/auth_session_coordinator.dart';
import '../coordinators/push_coordinator.dart';
import '../machines/auth/auth_adapters.dart';
import '../machines/auth/auth_machine.dart';
import '../machines/notifications/auth_notifications_effects.dart';
import '../machines/notifications/notifications_adapters.dart';
import '../machines/notifications/notifications_machine.dart';
import '../machines/multi-account/account_multi_account_effects.dart';
import '../machines/multi-account/multi_account_adapters.dart';
import '../machines/multi-account/multi_account_machine.dart';
import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/profile.dart';
import '../services/account_manager.dart';
import '../services/account_session.dart';
import '../services/navigation_coordinator.dart';
import '../utils/friendly_auth_error.dart';

/// Composition root: macchine, coordinatori, stato UI read-only.
class AuthController extends ChangeNotifier {
  AuthController({
    AccountManager? accountManager,
    NavigationCoordinator? navigation,
  }) : _manager = accountManager ?? AccountManager() {
    final multiAccountEffects = AccountMultiAccountEffects(_manager);
    multiAccountMachine = MultiAccountMachine(effects: multiAccountEffects);
    multiAccountAdapters = MultiAccountAdapters(
      multiAccountMachine,
      effects: multiAccountEffects,
    );
    _navigation = navigation ??
        NavigationCoordinator(
          _manager,
          focusCommand: multiAccountAdapters,
        );
    _manager.onFocusedProfileSynced = notifyListeners;
    final notificationEffects = AuthNotificationsEffects(this);
    notificationsMachine = NotificationsMachine(effects: notificationEffects);
    notificationsAdapters = NotificationsAdapters(notificationsMachine);
    authMachine = AuthMachine();
    authAdapters = AuthAdapters(authMachine);
    _sessionState = AuthSessionState();
    _pushCoordinator = PushCoordinator(
      manager: _manager,
      notificationsMachine: notificationsMachine,
    );
    _sessionCoordinator = AuthSessionCoordinator(
      manager: _manager,
      authMachine: authMachine,
      authAdapters: authAdapters,
      multiAccountAdapters: multiAccountAdapters,
      pushCoordinator: _pushCoordinator,
      state: _sessionState,
      onStateChanged: notifyListeners,
    );
  }

  final AccountManager _manager;
  late final NavigationCoordinator _navigation;
  late final AuthSessionState _sessionState;
  late final PushCoordinator _pushCoordinator;
  late final AuthSessionCoordinator _sessionCoordinator;
  late final NotificationsMachine notificationsMachine;
  late final NotificationsAdapters notificationsAdapters;
  late final MultiAccountMachine multiAccountMachine;
  late final MultiAccountAdapters multiAccountAdapters;
  late final AuthMachine authMachine;
  late final AuthAdapters authAdapters;

  @visibleForTesting
  NavigationCoordinator get navigation => _navigation;

  ExternalIntentAdapter get externalIntents => _navigation.externalIntents;

  bool get isLoading => _sessionState.isLoading;
  set isLoading(bool value) => _sessionState.isLoading = value;

  bool get sessionReady => _sessionState.sessionReady;
  set sessionReady(bool value) => _sessionState.sessionReady = value;

  String? get error => _sessionState.error;
  set error(String? value) => _sessionState.error = value;

  bool get showAuthOverlay => _sessionState.showAuthOverlay;
  set showAuthOverlay(bool value) => _sessionState.showAuthOverlay = value;

  bool get authOverlayDismissible => _sessionState.authOverlayDismissible;
  set authOverlayDismissible(bool value) =>
      _sessionState.authOverlayDismissible = value;

  AccountManager get accountManager => _manager;

  List<OpenAccount> get openAccounts => _manager.openAccounts;
  AccountSession? get focusedSession => _manager.focusedSession;
  String? get userId => _manager.focusUserId;
  AccountViewState get viewState => _manager.viewState;
  ChatPeer? get activePeer => _manager.viewState.activePeer;
  bool get showInboxOnMobile => _manager.viewState.showInboxOnMobile;
  bool get groupChatOpen => _manager.viewState.groupChatOpen;
  bool get hasOpenAccounts => _manager.hasOpenAccounts;

  UserProfile? get profile => focusedSession?.fullProfile;

  String? get email => focusedSession?.client.auth.currentUser?.email;
  String? get username => focusedSession?.profile.username;

  Future<void> syncPushSubscriptions() =>
      _pushCoordinator.syncPushSubscriptions();

  Future<void> initialize() => _sessionCoordinator.initialize();

  void openAuthOverlay({required bool dismissible}) =>
      _sessionCoordinator.openAuthOverlay(dismissible: dismissible);

  void closeAuthOverlay() => _sessionCoordinator.closeAuthOverlay(
        hasOpenAccounts: _manager.hasOpenAccounts,
      );

  Future<void> setFocus(String userId) async {
    try {
      await multiAccountAdapters.focusAccount(userId);
      error = null;
    } catch (e) {
      error = friendlyAuthError(e);
    }
    notifyListeners();
  }

  Future<void> reconnectFocusedSession() async {
    if (!hasOpenAccounts || focusedSession != null) return;
    try {
      await multiAccountAdapters.reconnectFocusedSession();
      error = null;
    } catch (e) {
      error = friendlyAuthError(e);
    }
    notifyListeners();
  }

  Future<bool> focusAccountForPushNotification(String recipientUserId) async {
    try {
      final ok = await _navigation.ensureAccountFocused(recipientUserId);
      if (ok) {
        error = null;
      }
      notifyListeners();
      return ok;
    } catch (e) {
      error = friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> openConversationAfterPushTap({
    required String recipientUserId,
    required String peerProfileId,
  }) async {
    try {
      final ok = await _navigation.externalIntents.openFromPushTap(
        accountUserId: recipientUserId,
        peerProfileId: peerProfileId,
      );
      if (ok) error = null;
      notifyListeners();
      return ok;
    } catch (e) {
      error = friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    try {
      final ok = await _navigation.openFromCompose(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
        allowProfileFallback: allowProfileFallback,
      );
      if (ok) error = null;
      notifyListeners();
      return ok;
    } catch (e) {
      error = friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> openConversationFromShareableLink({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    try {
      final ok = await _navigation.externalIntents.openFromShareableLink(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
      );
      if (ok) error = null;
      notifyListeners();
      return ok;
    } catch (e) {
      error = friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  void openConversation(ChatPeer peer) {
    _navigation.openPeerOnFocusedAccount(peer);
    notifyListeners();
  }

  void backToInboxOnMobile() {
    unawaited(_navigation.closeConversation());
    notifyListeners();
  }

  void openGroupChat() {
    unawaited(_navigation.openGroupChat());
    notifyListeners();
  }

  void backToGroupHome() {
    unawaited(_navigation.backToGroupHome());
    notifyListeners();
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    _navigation.adapters.mergeActivePeerFromInbox(inboxRow);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _sessionCoordinator.signIn(email, password);

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) =>
      _sessionCoordinator.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        profileKind: profileKind,
      );

  Future<bool> resetPassword(String email) =>
      _sessionCoordinator.resetPassword(email);

  Future<void> removeAccount(String userId) =>
      _sessionCoordinator.removeAccount(userId);

  Future<void> refreshProfile() async {
    await focusedSession?.syncProfileSummary();
    focusedSession?.fullProfile = await focusedSession?.fetchFullProfile();
    await _manager.refreshOpenAccountProfiles();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_manager.dispose());
    super.dispose();
  }
}
