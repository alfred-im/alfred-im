// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/profile_summary.dart';
import 'multi_account_effects.dart';

/// Stato focus account — `docs/model/uml/multi-account/multi-account-state.puml`.
enum MultiAccountFocusState {
  noOpenAccounts,
  hasOpenAccounts,
  focusSwitching,
  focusedWithSession,
  focusedAwaitingSession,
}

/// Eventi — stessi nomi di `docs/domain/multi-account/commands-and-events.md`.
sealed class MultiAccountEvent {
  const MultiAccountEvent();
}

/// Manifest letto da storage; la macchina decide [focusUserId].
final class ManifestLoaded extends MultiAccountEvent {
  const ManifestLoaded({
    required this.openAccountUserIds,
    this.persistedFocusUserId,
  });

  final List<String> openAccountUserIds;
  final String? persistedFocusUserId;
}

/// Sessione GoTrue attivata (o meno) per il focus corrente.
final class FocusActivationCompleted extends MultiAccountEvent {
  const FocusActivationCompleted({required this.hasFocusedSession});

  final bool hasFocusedSession;
}

final class FocusAccount extends MultiAccountEvent {
  const FocusAccount(this.accountUserId);
  final String accountUserId;
}

final class AccountFocused extends MultiAccountEvent {
  const AccountFocused();
}

final class SessionRestoreFailed extends MultiAccountEvent {
  const SessionRestoreFailed();
}

final class AccountOpened extends MultiAccountEvent {
  const AccountOpened({
    required this.accountUserId,
    required this.sessionReady,
  });

  final String accountUserId;
  final bool sessionReady;
}

final class AccountClosed extends MultiAccountEvent {
  const AccountClosed({
    required this.wasLastAccount,
    required this.sessionReady,
  });

  final bool wasLastAccount;
  final bool sessionReady;
}

final class ReconnectFocusedSession extends MultiAccountEvent {
  const ReconnectFocusedSession();
}

final class OpenAccountWithPassword extends MultiAccountEvent {
  const OpenAccountWithPassword({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

final class OpenAccountWithSignUp extends MultiAccountEvent {
  const OpenAccountWithSignUp({
    required this.email,
    required this.password,
    required this.username,
    required this.displayName,
    this.profileKind = ProfileKind.user,
  });

  final String email;
  final String password;
  final String username;
  final String displayName;
  final ProfileKind profileKind;
}

final class CloseAccount extends MultiAccountEvent {
  const CloseAccount(this.accountUserId);
  final String accountUserId;
}

/// Macchina multi-account — fonte di verità per focus intent e stato sessione.
class MultiAccountMachine {
  MultiAccountMachine({this._effects});

  final MultiAccountEffects? _effects;

  MultiAccountFocusState focusState = MultiAccountFocusState.noOpenAccounts;

  /// Intent focus UI — persistito via effetti su [AccountManager].
  String? focusUserId;

  /// Risolve focus da manifest (usato da adapter bootstrap).
  static String? resolveFocusUserId({
    required List<String> openAccountUserIds,
    String? persistedFocusUserId,
  }) {
    if (openAccountUserIds.isEmpty) return null;
    if (persistedFocusUserId != null &&
        openAccountUserIds.contains(persistedFocusUserId)) {
      return persistedFocusUserId;
    }
    return openAccountUserIds.first;
  }

  Future<void> send(MultiAccountEvent event) async {
    switch (event) {
      case ManifestLoaded(
        :final openAccountUserIds,
        :final persistedFocusUserId,
      ):
        _applyManifestLoaded(
          openAccountUserIds: openAccountUserIds,
          persistedFocusUserId: persistedFocusUserId,
        );
      case FocusActivationCompleted(:final hasFocusedSession):
        _applyFocusActivationCompleted(hasFocusedSession: hasFocusedSession);
      case FocusAccount(:final accountUserId):
        await _handleFocusAccount(accountUserId);
      case AccountFocused():
        _applyAccountFocused();
      case SessionRestoreFailed():
        _applySessionRestoreFailed();
      case AccountOpened(:final accountUserId, :final sessionReady):
        _applyAccountOpened(
          accountUserId: accountUserId,
          sessionReady: sessionReady,
        );
      case AccountClosed(:final wasLastAccount, :final sessionReady):
        _applyAccountClosed(
          wasLastAccount: wasLastAccount,
          sessionReady: sessionReady,
        );
      case ReconnectFocusedSession():
        await _handleReconnectFocusedSession();
      case OpenAccountWithPassword(:final email, :final password):
        await _handleOpenAccountWithPassword(email: email, password: password);
      case OpenAccountWithSignUp(
        :final email,
        :final password,
        :final username,
        :final displayName,
        :final profileKind,
      ):
        await _handleOpenAccountWithSignUp(
          email: email,
          password: password,
          username: username,
          displayName: displayName,
          profileKind: profileKind,
        );
      case CloseAccount(:final accountUserId):
        await _handleCloseAccount(accountUserId);
    }
  }

  Future<void> _handleFocusAccount(String accountUserId) async {
    if (focusState == MultiAccountFocusState.noOpenAccounts) return;

    focusUserId = accountUserId;
    focusState = MultiAccountFocusState.focusSwitching;

    final effects = _effects;
    if (effects == null) {
      focusState = MultiAccountFocusState.focusedAwaitingSession;
      return;
    }

    try {
      await effects.executeFocus(accountUserId);
      if (effects.hasFocusedSession) {
        _applyAccountFocused();
      } else {
        _applySessionRestoreFailed();
      }
    } catch (_) {
      focusUserId = effects.focusUserId;
      if (effects.hasFocusedSession) {
        _applyAccountFocused();
      } else {
        _applySessionRestoreFailed();
      }
      rethrow;
    }
  }

  Future<void> _handleReconnectFocusedSession() async {
    if (focusState != MultiAccountFocusState.focusedAwaitingSession) return;

    final focus = focusUserId;
    if (focus == null) return;

    final effects = _effects;
    if (effects == null) return;

    await effects.reconnectFocusedSession(focus);
    if (effects.hasFocusedSession) {
      _applyAccountFocused();
    }
  }

  Future<void> _handleOpenAccountWithPassword({
    required String email,
    required String password,
  }) async {
    final effects = _effects;
    if (effects == null) return;

    final userId = await effects.openAccountWithPassword(
      email: email,
      password: password,
    );
    focusUserId = userId;
    await effects.executeFocus(userId);
    _applyAccountOpened(
      accountUserId: userId,
      sessionReady: effects.hasFocusedSession,
    );
  }

  Future<void> _handleOpenAccountWithSignUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required ProfileKind profileKind,
  }) async {
    final effects = _effects;
    if (effects == null) return;

    final userId = await effects.openAccountWithSignUp(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
      profileKind: profileKind,
    );
    focusUserId = userId;
    await effects.executeFocus(userId);
    _applyAccountOpened(
      accountUserId: userId,
      sessionReady: effects.hasFocusedSession,
    );
  }

  Future<void> _handleCloseAccount(String accountUserId) async {
    final effects = _effects;
    if (effects == null) return;

    final result = await effects.closeAccount(accountUserId);

    if (result.wasLastAccount) {
      focusUserId = null;
      _applyAccountClosed(wasLastAccount: true, sessionReady: false);
      return;
    }

    if (result.wasFocused && result.remainingUserIds.isNotEmpty) {
      focusUserId = result.remainingUserIds.first;
      focusState = MultiAccountFocusState.focusSwitching;
      await effects.executeFocus(focusUserId!);
    }

    _applyAccountClosed(
      wasLastAccount: false,
      sessionReady: effects.hasFocusedSession,
    );
  }

  void _applyManifestLoaded({
    required List<String> openAccountUserIds,
    String? persistedFocusUserId,
  }) {
    focusUserId = resolveFocusUserId(
      openAccountUserIds: openAccountUserIds,
      persistedFocusUserId: persistedFocusUserId,
    );
    if (focusUserId == null) {
      focusState = MultiAccountFocusState.noOpenAccounts;
    } else {
      focusState = MultiAccountFocusState.hasOpenAccounts;
    }
  }

  void _applyFocusActivationCompleted({required bool hasFocusedSession}) {
    if (focusUserId == null) {
      focusState = MultiAccountFocusState.noOpenAccounts;
    } else if (hasFocusedSession) {
      focusState = MultiAccountFocusState.focusedWithSession;
    } else {
      focusState = MultiAccountFocusState.focusedAwaitingSession;
    }
  }

  void _applyAccountOpened({
    required String accountUserId,
    required bool sessionReady,
  }) {
    focusUserId = accountUserId;
    if (focusState == MultiAccountFocusState.noOpenAccounts) {
      focusState = sessionReady
          ? MultiAccountFocusState.focusedWithSession
          : MultiAccountFocusState.hasOpenAccounts;
      return;
    }
    if (sessionReady) {
      focusState = MultiAccountFocusState.focusedWithSession;
    }
  }

  void _applyAccountFocused() {
    focusState = MultiAccountFocusState.focusedWithSession;
  }

  void _applySessionRestoreFailed() {
    switch (focusState) {
      case MultiAccountFocusState.focusSwitching:
      case MultiAccountFocusState.hasOpenAccounts:
        focusState = MultiAccountFocusState.focusedAwaitingSession;
      case MultiAccountFocusState.noOpenAccounts:
      case MultiAccountFocusState.focusedWithSession:
      case MultiAccountFocusState.focusedAwaitingSession:
        break;
    }
  }

  void _applyAccountClosed({
    required bool wasLastAccount,
    required bool sessionReady,
  }) {
    if (wasLastAccount) {
      focusUserId = null;
      focusState = MultiAccountFocusState.noOpenAccounts;
      return;
    }
    focusState = sessionReady
        ? MultiAccountFocusState.focusedWithSession
        : MultiAccountFocusState.focusedAwaitingSession;
  }
}
