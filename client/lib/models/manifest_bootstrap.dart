// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Snapshot manifest per bootstrap macchina (solo lettura storage).
class ManifestBootstrap {
  const ManifestBootstrap({
    required this.openAccountUserIds,
    this.persistedFocusUserId,
  });

  final List<String> openAccountUserIds;
  final String? persistedFocusUserId;
}

/// Esito rimozione account dal manifest.
class CloseAccountResult {
  const CloseAccountResult({
    required this.wasLastAccount,
    required this.wasFocused,
    required this.remainingUserIds,
  });

  final bool wasLastAccount;
  final bool wasFocused;
  final List<String> remainingUserIds;
}
