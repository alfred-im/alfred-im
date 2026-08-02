// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../services/session_authority.dart';

/// Blocca sync push durante picker media / upload.
///
/// Delega a [SessionAuthority] quando collegato; fallback depth per test isolati.
class PushMediaSyncGuard {
  static SessionAuthority? _authority;
  static int _fallbackDepth = 0;

  static void bind(SessionAuthority authority) {
    _authority = authority;
  }

  static bool get isActive =>
      _authority?.hasActiveLease ?? _fallbackDepth > 0;

  static Future<T> run<T>(
    Future<T> Function() action, {
    String? ownerUserId,
    IdentityLeaseReason reason = IdentityLeaseReason.mediaPicker,
  }) async {
    final authority = _authority;
    final owner = ownerUserId ?? authority?.activeOwnerId;
    if (authority != null && owner != null) {
      return authority.runWithLease(owner, reason, action);
    }

    _fallbackDepth++;
    try {
      return await action();
    } finally {
      _fallbackDepth--;
    }
  }
}
