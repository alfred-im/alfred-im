// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../services/account_manager.dart';

/// Stato focus account — `docs/model/uml/multi-account/multi-account-state.puml`.
enum MultiAccountFocusState {
  noOpenAccounts,
  focusedWithSession,
  focusedAwaitingSession,
  focusSwitching,
}

sealed class MultiAccountEvent {
  const MultiAccountEvent();
}

final class ManifestInitialized extends MultiAccountEvent {
  const ManifestInitialized({
    required this.hasOpenAccounts,
    required this.hasFocusedSession,
  });

  final bool hasOpenAccounts;
  final bool hasFocusedSession;
}

final class FocusAccountRequested extends MultiAccountEvent {
  const FocusAccountRequested(this.accountUserId);
  final String accountUserId;
}

final class FocusAccountCompleted extends MultiAccountEvent {
  const FocusAccountCompleted({required this.sessionReady});
  final bool sessionReady;
}

/// Macchina multi-account — traccia focus e sessione GoTrue.
class MultiAccountMachine {
  MultiAccountMachine({this._manager});

  final AccountManager? _manager;

  MultiAccountFocusState focusState = MultiAccountFocusState.noOpenAccounts;

  void send(MultiAccountEvent event) {
    switch (event) {
      case ManifestInitialized(
        :final hasOpenAccounts,
        :final hasFocusedSession,
      ):
        if (!hasOpenAccounts) {
          focusState = MultiAccountFocusState.noOpenAccounts;
        } else if (hasFocusedSession) {
          focusState = MultiAccountFocusState.focusedWithSession;
        } else {
          focusState = MultiAccountFocusState.focusedAwaitingSession;
        }
      case FocusAccountRequested():
        if (focusState != MultiAccountFocusState.noOpenAccounts) {
          focusState = MultiAccountFocusState.focusSwitching;
        }
      case FocusAccountCompleted(:final sessionReady):
        focusState = sessionReady
            ? MultiAccountFocusState.focusedWithSession
            : MultiAccountFocusState.focusedAwaitingSession;
    }
  }

  void syncFromManager() {
    final manager = _manager;
    if (manager == null) return;
    send(
      ManifestInitialized(
        hasOpenAccounts: manager.hasOpenAccounts,
        hasFocusedSession: manager.focusedSession != null,
      ),
    );
  }
}
