// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/profile_summary.dart';
import 'multi_account_effects.dart';
import 'multi_account_machine.dart';

/// Comando focus account — implementato da [MultiAccountAdapters] per navigation.
abstract class AccountFocusCommand {
  Future<void> focusAccount(String accountUserId);
}

/// Mappa ingressi attuali → eventi macchina multi-account.
///
/// UML: `docs/model/uml/multi-account/seq-focus-switch.puml`
class MultiAccountAdapters implements AccountFocusCommand {
  MultiAccountAdapters(this._machine, {required this.effects});

  final MultiAccountMachine _machine;
  final MultiAccountEffects effects;

  /// F5 / avvio: carica manifest, macchina decide focus, effetti attivano sessione.
  Future<void> bootstrapManifest() async {
    final bootstrap = await effects.loadManifestBootstrap();
    await _machine.send(
      ManifestLoaded(
        openAccountUserIds: bootstrap.openAccountUserIds,
        persistedFocusUserId: bootstrap.persistedFocusUserId,
      ),
    );

    final focus = _machine.focusUserId;
    if (focus != null) {
      await effects.executeFocus(focus);
    }

    await _machine.send(
      FocusActivationCompleted(hasFocusedSession: effects.hasFocusedSession),
    );
  }

  @override
  Future<void> focusAccount(String accountUserId) {
    return _machine.send(FocusAccount(accountUserId));
  }

  Future<void> reconnectFocusedSession() {
    return _machine.send(const ReconnectFocusedSession());
  }

  Future<void> openAccountWithPassword({
    required String email,
    required String password,
  }) {
    return _machine.send(
      OpenAccountWithPassword(email: email, password: password),
    );
  }

  Future<void> openAccountWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    ProfileKind profileKind = ProfileKind.user,
  }) {
    return _machine.send(
      OpenAccountWithSignUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        profileKind: profileKind,
      ),
    );
  }

  Future<void> closeAccount(String accountUserId) {
    return _machine.send(CloseAccount(accountUserId));
  }
}
