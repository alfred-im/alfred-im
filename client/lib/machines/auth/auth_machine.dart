// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Stato UI auth — `docs/model/uml/auth/auth-state.puml`.
enum AuthUiState {
  bootstrapping,
  noSession,
  sessionActive,
  overlayVisible,
  authOperationInProgress,
}

sealed class AuthEvent {
  const AuthEvent();
}

final class BootstrapStarted extends AuthEvent {
  const BootstrapStarted();
}

final class BootstrapCompleted extends AuthEvent {
  const BootstrapCompleted({required this.hasOpenAccounts});

  final bool hasOpenAccounts;
}

final class OverlayOpenRequested extends AuthEvent {
  const OverlayOpenRequested({required this.dismissible});

  final bool dismissible;
}

final class OverlayCloseRequested extends AuthEvent {
  const OverlayCloseRequested();
}

final class LastAccountRemoved extends AuthEvent {
  const LastAccountRemoved();
}

final class ValidationRejected extends AuthEvent {
  const ValidationRejected();
}

final class AuthOperationStarted extends AuthEvent {
  const AuthOperationStarted();
}

final class AuthOperationCompleted extends AuthEvent {
  const AuthOperationCompleted({required this.success});

  final bool success;
}

final class AuthOperationFailed extends AuthEvent {
  const AuthOperationFailed();
}

/// Macchina auth — overlay e sessione UI (SURF-AUTH).
class AuthMachine {
  AuthUiState uiState = AuthUiState.bootstrapping;
  AuthUiState? _preOperationState;

  bool get showOverlay =>
      uiState == AuthUiState.noSession ||
      uiState == AuthUiState.overlayVisible;

  bool get overlayDismissible => uiState == AuthUiState.overlayVisible;

  bool get isBootstrapping => uiState == AuthUiState.bootstrapping;

  bool get isAuthOperationInProgress =>
      uiState == AuthUiState.authOperationInProgress;

  void send(AuthEvent event) {
    switch (event) {
      case BootstrapStarted():
        uiState = AuthUiState.bootstrapping;
      case BootstrapCompleted(:final hasOpenAccounts):
        uiState = hasOpenAccounts
            ? AuthUiState.sessionActive
            : AuthUiState.noSession;
      case OverlayOpenRequested(:final dismissible):
        uiState = dismissible
            ? AuthUiState.overlayVisible
            : AuthUiState.noSession;
      case OverlayCloseRequested():
        _handleOverlayClose();
      case ValidationRejected():
        if (uiState == AuthUiState.authOperationInProgress) {
          _restorePreOperationState();
          _preOperationState = null;
        }
      case AuthOperationStarted():
        _beginAuthOperation();
      case AuthOperationCompleted(:final success):
        if (success) {
          uiState = AuthUiState.sessionActive;
        } else {
          _restorePreOperationState();
        }
        _preOperationState = null;
      case AuthOperationFailed():
        _restorePreOperationState();
        _preOperationState = null;
      case LastAccountRemoved():
        uiState = AuthUiState.noSession;
    }
  }

  void _handleOverlayClose() {
    switch (uiState) {
      case AuthUiState.overlayVisible:
        uiState = AuthUiState.sessionActive;
      case AuthUiState.noSession:
        break;
      default:
        if (uiState != AuthUiState.bootstrapping &&
            uiState != AuthUiState.authOperationInProgress) {
          uiState = AuthUiState.sessionActive;
        }
    }
  }

  void _beginAuthOperation() {
    if (uiState == AuthUiState.authOperationInProgress) return;
    _preOperationState = uiState;
    uiState = AuthUiState.authOperationInProgress;
  }

  void _restorePreOperationState() {
    final previous = _preOperationState;
    if (previous != null && previous != AuthUiState.authOperationInProgress) {
      uiState = previous;
    } else if (previous == null) {
      uiState = AuthUiState.sessionActive;
    }
  }
}
