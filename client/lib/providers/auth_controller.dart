// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../machines/notifications/auth_notifications_effects.dart';
import '../machines/notifications/notifications_adapters.dart';
import '../machines/notifications/notifications_machine.dart';
import '../machines/multi-account/multi_account_machine.dart';
import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/profile.dart';
import '../services/account_manager.dart';
import '../services/account_session.dart';
import '../services/navigation_coordinator.dart';
import '../services/push_subscription_service.dart';
import '../utils/auth_identity.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    AccountManager? accountManager,
    NavigationCoordinator? navigation,
  }) : _manager = accountManager ?? AccountManager() {
    _navigation = navigation ?? NavigationCoordinator(_manager);
    _manager.onFocusedProfileSynced = notifyListeners;
    final effects = AuthNotificationsEffects(this);
    notificationsMachine = NotificationsMachine(effects: effects);
    notificationsAdapters = NotificationsAdapters(notificationsMachine);
    multiAccountMachine = MultiAccountMachine(manager: _manager);
  }

  final AccountManager _manager;
  late final NavigationCoordinator _navigation;
  final PushSubscriptionService _pushService = PushSubscriptionService();
  late final NotificationsMachine notificationsMachine;
  late final NotificationsAdapters notificationsAdapters;
  late final MultiAccountMachine multiAccountMachine;

  @visibleForTesting
  NavigationCoordinator get navigation => _navigation;

  bool isLoading = true;
  bool sessionReady = false;
  String? error;

  bool showAuthOverlay = false;
  bool authOverlayDismissible = false;

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

  /// Re-registra subscription push (es. dopo resume PWA o permesso concesso).
  Future<void> syncPushSubscriptions() async {
    if (kIsWeb) {
      _applyPushEnvironmentToMachine();
      if (!shouldAttemptPushSubscription(
        isPushSupported: PushPlatform.isPushSupported,
        notificationPermission: PushPlatform.notificationPermission,
      )) {
        return;
      }
    }

    notificationsMachine.send(const SyncSubscriptionsRequested());
    try {
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        focusedSession: _manager.focusedSession,
      );
      notificationsMachine.send(const SubscriptionRegistered());
    } catch (_) {
      notificationsMachine.send(const SubscriptionSyncFailed());
    }
  }

  void _applyPushEnvironmentToMachine() {
    if (!PushPlatform.isPushSupported) {
      notificationsMachine.send(const PushUnsupportedDetected());
    } else if (PushPlatform.notificationPermission == 'denied') {
      notificationsMachine.send(const PermissionDeniedDetected());
    } else {
      notificationsMachine.send(const SubscriptionIdleReached());
    }
  }

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      await _manager.initialize();
      if (!_manager.hasOpenAccounts) {
        showAuthOverlay = true;
        authOverlayDismissible = false;
      }
    } finally {
      isLoading = false;
      sessionReady = true;
      multiAccountMachine.syncFromManager();
      notifyListeners();
    }
    unawaited(syncPushSubscriptions());
  }

  void openAuthOverlay({required bool dismissible}) {
    showAuthOverlay = true;
    authOverlayDismissible = dismissible;
    error = null;
    notifyListeners();
  }

  void closeAuthOverlay() {
    if (!authOverlayDismissible && !_manager.hasOpenAccounts) return;
    showAuthOverlay = false;
    error = null;
    notifyListeners();
  }

  Future<void> setFocus(String userId) async {
    multiAccountMachine.send(FocusAccountRequested(userId));
    try {
      await _navigation.switchToAccount(userId);
      error = null;
    } catch (e) {
      error = _friendlyAuthError(e);
    }
    multiAccountMachine.send(
      FocusAccountCompleted(sessionReady: _manager.focusedSession != null),
    );
    notifyListeners();
  }

  /// Tap notifica push: focus sull'account destinatario (delega a [NavigationCoordinator]).
  Future<bool> focusAccountForPushNotification(String recipientUserId) async {
    try {
      final ok = await _navigation.ensureAccountFocused(recipientUserId);
      if (ok) {
        error = null;
      }
      notifyListeners();
      return ok;
    } catch (e) {
      error = _friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  /// Tap push: account destinatario → inbox → conversazione (solo peer in inbox).
  Future<bool> openConversationAfterPushTap({
    required String recipientUserId,
    required String peerProfileId,
  }) async {
    try {
      final ok = await _navigation.adapters.openFromPushTap(
        accountUserId: recipientUserId,
        peerProfileId: peerProfileId,
      );
      if (ok) error = null;
      notifyListeners();
      return ok;
    } catch (e) {
      error = _friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  /// Apre conversazione su account specifico (link condivisibili, compose).
  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    try {
      final ok = await _navigation.openConversationOnAccount(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
        allowProfileFallback: allowProfileFallback,
      );
      if (ok) error = null;
      notifyListeners();
      return ok;
    } catch (e) {
      error = _friendlyAuthError(e);
      notifyListeners();
      return false;
    }
  }

  void openConversation(ChatPeer peer) {
    _navigation.openPeerOnFocusedAccount(peer);
    notifyListeners();
  }

  void backToInboxOnMobile() {
    _manager.showInboxOnMobile();
    notifyListeners();
  }

  void openGroupChat() {
    _manager.openGroupChat();
    notifyListeners();
  }

  void backToGroupHome() {
    _manager.backToGroupHome();
    notifyListeners();
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    _manager.mergeActivePeerFromInbox(inboxRow);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return;
    }

    await _withLoading(() async {
      await _manager.openWithPassword(email: email, password: password);
      showAuthOverlay = false;
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        focusedSession: _manager.focusedSession,
      );
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) async {
    final emailError = AuthIdentity.validateEmail(email);
    if (emailError != null) {
      error = emailError;
      notifyListeners();
      return;
    }

    final usernameError = AuthIdentity.validateUsername(username);
    if (usernameError != null) {
      error = usernameError;
      notifyListeners();
      return;
    }

    if (displayName.trim().isEmpty) {
      error = 'Inserisci un nome visualizzato';
      notifyListeners();
      return;
    }

    await _withLoading(() async {
      final available = await _manager.isUsernameAvailable(username);
      if (!available) {
        throw const AuthException('Username già in uso. Scegline un altro.');
      }
      await _manager.openWithSignUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName.trim(),
        profileKind: profileKind,
      );
      showAuthOverlay = false;
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        focusedSession: _manager.focusedSession,
      );
    });
  }

  Future<bool> resetPassword(String email) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      error = validationError;
      notifyListeners();
      return false;
    }

    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await _manager.resetPassword(email);
      return true;
    } catch (e) {
      error = _friendlyAuthError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeAccount(String userId) async {
    OpenAccount? account;
    for (final entry in _manager.openAccounts) {
      if (entry.userId == userId) {
        account = entry;
        break;
      }
    }
    final remaining =
        _manager.openAccounts.where((a) => a.userId != userId).length;
    await _pushService.unregisterAccount(
      userId: userId,
      account: account,
      isLastAccountOnDevice: remaining == 0,
    );
    notificationsMachine.send(const UnregisterSubscriptionRequested());
    await _manager.removeAccount(userId);
    if (!_manager.hasOpenAccounts) {
      showAuthOverlay = true;
      authOverlayDismissible = false;
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await focusedSession?.syncProfileSummary();
    focusedSession?.fullProfile = await focusedSession?.fetchFullProfile();
    await _manager.refreshOpenAccountProfiles();
    notifyListeners();
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    error = null;
    isLoading = true;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = _friendlyAuthError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid refresh') ||
          msg.contains('refresh token not found') ||
          msg.contains('session expired') ||
          msg.contains('token has expired')) {
        return 'Sessione scaduta per questo account. Accedi di nuovo.';
      }
      if (msg.contains('invalid login credentials')) {
        return 'Email o password non corretti.';
      }
      if (msg.contains('username già in uso')) {
        return 'Username già in uso. Scegline un altro.';
      }
      if (msg.contains('database error saving new user')) {
        return 'Username già in uso o non valido. Scegline un altro.';
      }
      if (msg.contains('user already registered')) {
        return 'Email già registrata. Prova ad accedere.';
      }
      if (msg.contains('email rate limit exceeded') ||
          msg.contains('over_email_send_rate_limit')) {
        return 'Troppi tentativi email. Riprova tra qualche minuto.';
      }
      if (msg.contains('conferma l\'email')) {
        return e.message;
      }
      return e.message;
    }
    return e.toString();
  }

  @override
  void dispose() {
    unawaited(_manager.dispose());
    super.dispose();
  }
}
