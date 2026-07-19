// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Callback multi-account → navigation per il ciclo di vita dello scope conversazione.
abstract class NavigationScopeHost {
  void invalidateCommittedScope();

  /// Dopo bootstrap / reconnect / focus switch: riallinea scope da view-state.
  void restoreCommittedScopeAfterFocusSettled();
}
