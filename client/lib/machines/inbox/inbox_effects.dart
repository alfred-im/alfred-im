// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Effetti inbox → [InboxCoordinator] e servizi collegati.
abstract class InboxEffects {
  Future<void> loadInbox({
    required int generation,
    required bool showLoadingIndicator,
  });
}
