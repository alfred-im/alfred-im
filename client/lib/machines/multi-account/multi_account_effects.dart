// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/manifest_bootstrap.dart';
import '../../models/profile_summary.dart';

/// Effetti collaterali del contesto multi-account → [AccountManager].
abstract class MultiAccountEffects {
  Future<ManifestBootstrap> loadManifestBootstrap();

  /// Esegue focus I/O (persist + dispose + restore) per [userId] deciso dalla macchina.
  Future<void> executeFocus(
    String userId, {
    bool deferProfileSync = false,
  });

  Future<void> reconnectFocusedSession(String focusUserId);

  Future<String> openAccountWithPassword({
    required String email,
    required String password,
  });

  Future<String> openAccountWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  });

  Future<CloseAccountResult> closeAccount(String accountUserId);

  /// Dopo init o sync: sessione GoTrue attiva per il focus corrente.
  bool get hasFocusedSession;

  /// Manifest con almeno un account aperto.
  bool get hasOpenAccounts;

  /// Focus effettivo dopo I/O (storage / manager).
  String? get focusUserId;
}
