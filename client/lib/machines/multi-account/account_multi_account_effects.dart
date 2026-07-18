// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/profile_summary.dart';
import '../../services/account_manager.dart';
import 'multi_account_effects.dart';

/// Effetti multi-account → [AccountManager] (solo I/O).
class AccountMultiAccountEffects implements MultiAccountEffects {
  AccountMultiAccountEffects(this._manager);

  final AccountManager _manager;

  @override
  bool get hasFocusedSession => _manager.focusedSession != null;

  @override
  bool get hasOpenAccounts => _manager.hasOpenAccounts;

  @override
  String? get focusUserId => _manager.focusUserId;

  @override
  Future<ManifestBootstrap> loadManifestBootstrap() {
    return _manager.loadManifestBootstrap();
  }

  @override
  Future<void> executeFocus(String userId) {
    return _manager.executeFocus(userId);
  }

  @override
  Future<void> reconnectFocusedSession(String focusUserId) {
    return _manager.reconnectFocusedSession(focusUserId);
  }

  @override
  Future<String> openAccountWithPassword({
    required String email,
    required String password,
  }) {
    return _manager.signInAndUpsertManifest(email: email, password: password);
  }

  @override
  Future<String> openAccountWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) {
    return _manager.signUpAndUpsertManifest(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
      profileKind: profileKind,
    );
  }

  @override
  Future<CloseAccountResult> closeAccount(String accountUserId) {
    return _manager.removeAccount(accountUserId);
  }
}
