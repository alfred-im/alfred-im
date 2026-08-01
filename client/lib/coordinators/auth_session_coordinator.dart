// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../machines/notifications/notifications_adapters.dart';
import '../machines/auth/auth_adapters.dart';
import '../machines/auth/auth_machine.dart';
import '../machines/multi-account/multi_account_adapters.dart';
import '../models/open_account.dart';
import '../models/push_sync_scope.dart';
import '../models/profile_summary.dart';
import '../services/account_manager.dart';
import '../services/navigation_coordinator.dart';
import '../utils/auth_identity.dart';
import '../utils/friendly_auth_error.dart';
import 'push_coordinator.dart';

/// Stato sessione auth esposto alla UI tramite [AuthController].
class AuthSessionState {
  bool isLoading = true;
  bool sessionReady = false;
  String? error;
}

/// Orchestrazione bootstrap, login, signup e chiusura account.
class AuthSessionCoordinator {
  AuthSessionCoordinator({
    required this._manager,
    required this._authMachine,
    required this._authAdapters,
    required this._multiAccountAdapters,
    required this._pushCoordinator,
    required this._notificationsAdapters,
    required this._navigation,
    required this._state,
    required this._onStateChanged,
  });

  final AccountManager _manager;
  final AuthMachine _authMachine;
  final AuthAdapters _authAdapters;
  final MultiAccountAdapters _multiAccountAdapters;
  final PushCoordinator _pushCoordinator;
  final NotificationsAdapters _notificationsAdapters;
  final NavigationCoordinator _navigation;
  final AuthSessionState _state;
  final void Function() _onStateChanged;

  AuthSessionState get state => _state;

  Future<void> initialize() async {
    _authAdapters.onBootstrapStarted();
    _state.isLoading = true;
    _notify();
    try {
      await _multiAccountAdapters.bootstrapManifest();
      _authAdapters.onBootstrapCompleted(
        hasOpenAccounts: _manager.hasOpenAccounts,
      );
    } finally {
      _state.isLoading = false;
      _state.sessionReady = true;
      _notificationsAdapters.onSessionBecameReady();
      _notify();
    }
    unawaited(
      _pushCoordinator.syncPushSubscriptions(
        scope: PushSyncScope.allOpenAccounts,
        reason: PushSyncReason.sessionReady,
      ),
    );
  }

  void openAuthOverlay({required bool dismissible}) {
    _authAdapters.onOverlayOpen(dismissible: dismissible);
    _state.error = null;
    _notify();
  }

  void closeAuthOverlay({required bool hasOpenAccounts}) {
    if (!_authMachine.overlayDismissible && !hasOpenAccounts) return;
    _authAdapters.onOverlayClose();
    _state.error = null;
    _notify();
  }

  Future<void> signIn(String email, String password) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      _authAdapters.onValidationRejected();
      _state.error = validationError;
      _notify();
      return;
    }

    await _withLoading(() async {
      await _multiAccountAdapters.openAccountWithPassword(
        email: email,
        password: password,
      );
      _authAdapters.onAuthOperationCompleted(success: true);
      await _navigation.syncShellAfterFocusSettled();
      await _pushCoordinator.syncPushSubscriptions(
        scope: PushSyncScope.allOpenAccounts,
        reason: PushSyncReason.accountOpened,
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
      _authAdapters.onValidationRejected();
      _state.error = emailError;
      _notify();
      return;
    }

    final usernameError = AuthIdentity.validateUsername(username);
    if (usernameError != null) {
      _authAdapters.onValidationRejected();
      _state.error = usernameError;
      _notify();
      return;
    }

    if (displayName.trim().isEmpty) {
      _authAdapters.onValidationRejected();
      _state.error = 'Inserisci un nome visualizzato';
      _notify();
      return;
    }

    await _withLoading(() async {
      await _multiAccountAdapters.openAccountWithSignUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName.trim(),
        profileKind: profileKind,
      );
      _authAdapters.onAuthOperationCompleted(success: true);
      await _navigation.syncShellAfterFocusSettled();
      await _pushCoordinator.syncPushSubscriptions(
        scope: PushSyncScope.allOpenAccounts,
        reason: PushSyncReason.accountOpened,
      );
    });
  }

  Future<bool> resetPassword(String email) async {
    final validationError = AuthIdentity.validateEmail(email);
    if (validationError != null) {
      _state.error = validationError;
      _notify();
      return false;
    }

    _state.error = null;
    _state.isLoading = true;
    _notify();
    try {
      await _manager.resetPassword(email);
      return true;
    } catch (e) {
      _state.error = friendlyAuthError(e);
      return false;
    } finally {
      _state.isLoading = false;
      _notify();
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
    await _pushCoordinator.unregisterAccount(
      userId: userId,
      account: account,
      isLastAccountOnDevice: remaining == 0,
    );
    await _multiAccountAdapters.closeAccount(userId);
    if (!_manager.hasOpenAccounts) {
      _authAdapters.onLastAccountRemoved();
    } else {
      await _navigation.syncShellAfterFocusSettled();
    }
    _notify();
  }

  Future<void> _withLoading(Future<void> Function() action) async {
    _state.error = null;
    _authAdapters.onAuthOperationStarted();
    _state.isLoading = true;
    _notify();
    try {
      await action();
    } catch (e) {
      _authAdapters.onAuthOperationFailed();
      _state.error = friendlyAuthError(e);
    } finally {
      _state.isLoading = false;
      _notify();
    }
  }

  void _notify() => _onStateChanged();
}
