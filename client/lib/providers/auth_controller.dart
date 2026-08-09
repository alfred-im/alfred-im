// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../adapters/external_intent_adapter.dart';
import '../coordinators/auth_session_coordinator.dart';
import '../coordinators/navigation_session_access.dart';
import '../coordinators/push_coordinator.dart';
import '../machines/auth/auth_adapters.dart';
import '../machines/auth/auth_machine.dart';
import '../coordinators/auth_notifications_effects.dart';
import '../machines/notifications/notifications_adapters.dart';
import '../machines/notifications/notifications_machine.dart';
import '../machines/multi-account/account_multi_account_effects.dart';
import '../machines/multi-account/multi_account_adapters.dart';
import '../machines/multi-account/multi_account_machine.dart';
import '../machines/messaging/conversation_message_store.dart';
import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../models/profile.dart';
import '../models/push_sync_scope.dart';
import '../services/account_manager.dart';
import '../services/account_session.dart';
import '../coordinators/navigation_coordinator.dart';
import '../utils/friendly_auth_error.dart';
import '../utils/push_media_sync_guard.dart';

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
    _navigationAccess = NavigationSessionAccess(_navigation);
    multiAccountEffects.onFocusIdentityChanged = notifyListeners;
    _navigation.onStateChanged = notifyListeners;
    _manager.onFocusedProfileSynced = notifyListeners;
    final notificationEffects = AuthNotificationsEffects(this);
    notificationsMachine = NotificationsMachine(effects: notificationEffects);
    notificationsAdapters = NotificationsAdapters(notificationsMachine);
    authMachine = AuthMachine();
    authAdapters = AuthAdapters(authMachine);
    _sessionState = AuthSessionState();
    _pushCoordinator = PushCoordinator(
      manager: _manager,
    );
    PushMediaSyncGuard.bind(_manager.sessionAuthority);
    _sessionCoordinator = AuthSessionCoordinator(
      manager: _manager,
      authMachine: authMachine,
      authAdapters: authAdapters,
      multiAccountAdapters: multiAccountAdapters,
      pushCoordinator: _pushCoordinator,
      notificationsAdapters: notificationsAdapters,
      navigation: _navigation,
      state: _sessionState,
      onStateChanged: notifyListeners,
    );
  }

  final AccountManager _manager;
  late final NavigationCoordinator _navigation;
  late final NavigationSessionAccess _navigationAccess;
  late final AuthSessionState _sessionState;
  late final PushCoordinator _pushCoordinator;
  late final AuthSessionCoordinator _sessionCoordinator;
  late final NotificationsMachine notificationsMachine;
  late final NotificationsAdapters notificationsAdapters;
  late final MultiAccountMachine multiAccountMachine;
  late final MultiAccountAdapters multiAccountAdapters;
  late final AuthMachine authMachine;
  late final AuthAdapters authAdapters;

  NavigationSessionAccess get navigation => _navigationAccess;

  @visibleForTesting
  NavigationCoordinator get navigationCoordinator => _navigation;

  ExternalIntentAdapter get externalIntents => _navigation.externalIntents;

  bool get isLoading => _sessionState.isLoading;
  set isLoading(bool value) => _sessionState.isLoading = value;

  bool get sessionReady => _sessionState.sessionReady;
  set sessionReady(bool value) => _sessionState.sessionReady = value;

  String? get error => _sessionState.error;
  set error(String? value) => _sessionState.error = value;

  bool get showAuthOverlay => authMachine.showOverlay;

  bool get authOverlayDismissible => authMachine.overlayDismissible;

  AccountManager get accountManager => _manager;

  SessionAuthority get sessionAuthority => _manager.sessionAuthority;

  ConversationScope? get committedScope => _navigationAccess.committedScope;

  ConversationMessageStore get messageStore => _navigationAccess.messageStore;

  bool get isChatShellOpen => _navigationAccess.isChatShellOpen;

  bool isConversationReady({
    required AccountSession session,
    required ChatPeer peer,
  }) {
    return _navigationAccess.isConversationReady(session: session, peer: peer);
  }

  List<OpenAccount> get openAccounts => _manager.openAccounts;
  AccountSession? get focusedSession => _manager.focusedSession;
  String? get userId => _manager.focusUserId;

  OpenAccount? get focusedOpenAccount {
    final id = userId;
    if (id == null) return null;
    return _manager.openAccountFor(id);
  }

  bool get isFocusedAccountDisconnected =>
      focusedOpenAccount?.isDisconnected ?? false;

  AccountViewState get viewState => _manager.viewState;
  ChatPeer? get activePeer => _manager.viewState.activePeer;
  bool get showInboxOnMobile => _manager.viewState.showInboxOnMobile;
  bool get groupChatOpen => _manager.viewState.groupChatOpen;
  bool get hasOpenAccounts => _manager.hasOpenAccounts;

  UserProfile? get profile => focusedSession?.fullProfile;

  ProfileSummary? get focusedProfileSummary =>
      focusedSession?.profile ?? focusedOpenAccount?.profile;

  String? get email => focusedSession?.client.auth.currentUser?.email;
  String? get username => focusedSession?.profile.username;

  Future<void> syncPushSubscriptions({
    required PushSyncScope scope,
    required PushSyncReason reason,
    String? newAccountUserId,
  }) =>
      _pushCoordinator.syncPushSubscriptions(
        scope: scope,
        reason: reason,
        newAccountUserId: newAccountUserId,
      );

  Future<void> initialize() async {
    await _sessionCoordinator.initialize();
    final focus = multiAccountMachine.focusUserId;
    if (focus != null) {
      try {
        await _navigation.switchToAccount(
          focus,
          deferProfileSync: true,
        );
        error = null;
      } catch (e) {
        error = friendlyAuthError(e);
      }
    }
    await _sessionCoordinator.completeBootstrap();
    notifyListeners();
  }

  void openAuthOverlay({required bool dismissible}) =>
      _sessionCoordinator.openAuthOverlay(dismissible: dismissible);

  /// Account in focus disconnesso per errore sessione — riapre overlay credenziali.
  void promptReconnectFocusedAccount() {
    openAuthOverlay(dismissible: hasOpenAccounts);
  }

  void closeAuthOverlay() => _sessionCoordinator.closeAuthOverlay(
        hasOpenAccounts: _manager.hasOpenAccounts,
      );

  Future<void> setFocus(String userId) async {
    try {
      await _navigation.switchToAccount(userId);
      error = null;
      await _pushCoordinator.syncPushSubscriptions(
        scope: PushSyncScope.focusedAccount,
        reason: PushSyncReason.focusChanged,
      );
    } catch (e) {
      error = friendlyAuthError(e);
    }
    notifyListeners();
  }

  Future<void> reconnectFocusedSession() async {
    if (!hasOpenAccounts || focusedSession != null) return;
    try {
      await multiAccountAdapters.reconnectFocusedSession();
      await _navigation.syncShellAfterFocusSettled();
      error = null;
    } catch (e) {
      error = friendlyAuthError(e);
    }
    notifyListeners();
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

  Future<void> openConversation(ChatPeer peer) async {
    await _navigationAccess.openConversation(peer);
  }

  Future<void> backToInboxOnMobile() async {
    await _navigationAccess.backToInboxOnMobile();
  }

  Future<void> openGroupChat() async {
    await _navigationAccess.openGroupChat();
  }

  Future<void> backToGroupHome() async {
    await _navigationAccess.backToGroupHome();
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    _navigationAccess.mergeActivePeerFromInbox(inboxRow);
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
