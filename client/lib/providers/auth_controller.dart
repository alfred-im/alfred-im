// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../models/account_view_state.dart';
import '../models/chat_peer.dart';
import '../models/profile.dart';
import '../services/account_manager.dart';
import '../services/account_session.dart';
import '../utils/auth_identity.dart';

class AuthController extends ChangeNotifier {
  AuthController({AccountManager? accountManager})
      : _manager = accountManager ?? AccountManager() {
    _manager.onFocusedProfileSynced = notifyListeners;
  }

  final AccountManager _manager;

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
      notifyListeners();
    }
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
    try {
      await _manager.setFocus(userId);
      error = null;
    } catch (e) {
      error = _friendlyAuthError(e);
    }
    notifyListeners();
  }

  void openConversation(ChatPeer peer) {
    _manager.openConversation(peer);
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
