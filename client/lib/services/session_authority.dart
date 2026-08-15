// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

part of 'account_manager.dart';

/// Motivo di un lease identità — vedi docs/domain/multi-account/session-authority.md.
enum IdentityLeaseReason {
  mediaUpload,
  mediaPicker,
  other,
}

/// Lease che blocca switch verso altro focus durante operazioni lunghe.
class IdentityLease {
  const IdentityLease({
    required this.id,
    required this.focusUserId,
    required this.reason,
  });

  final String id;
  final String focusUserId;
  final IdentityLeaseReason reason;
}

/// Esito di [SessionAuthority.authorizePushSync].
class AuthorizePushSyncResult {
  const AuthorizePushSyncResult({
    required this.authorized,
    required this.deferred,
  });

  final bool authorized;
  final bool deferred;
}

/// Unico enforcement identità GoTrue — vedi docs/domain/multi-account/session-authority.md.
class SessionAuthority {
  SessionAuthority(this._manager);

  final AccountManager _manager;
  final List<IdentityLease> _leases = [];
  int _leaseCounter = 0;

  /// Focus account con JWT attivo in RAM (null se nessuna sessione).
  String? get activeFocusUserId => _manager.focusUserId;

  AccountSession? get focusedSession => _manager.focusedSession;

  /// Generazione identità — allineata a [AccountSession.epoch] della sessione attiva.
  int get identityGeneration => _manager.focusedSession?.epoch ?? 0;

  bool get hasActiveLease => _leases.isNotEmpty;

  String? get leaseFocusUserId =>
      _leases.isEmpty ? null : _leases.first.focusUserId;

  /// Serializza dispose + restore per cambio focus UI.
  Future<void> requestFocusSwitch(
    String userId, {
    bool deferProfileSync = false,
    VoidCallback? onFocusIdentityChanged,
  }) async {
    if (_blocksSwitchTo(userId)) {
      throw StateError(
        'Identity switch deferred: lease active for ${leaseFocusUserId!}',
      );
    }
    await _manager._executeFocus(
      userId,
      deferProfileSync: deferProfileSync,
      onFocusIdentityChanged: onFocusIdentityChanged,
    );
  }

  /// Garantisce JWT per [focusUserId] prima di [operation].
  Future<T> runAsFocus<T>(
    String focusUserId,
    Future<T> Function() operation, {
    bool restorePreviousFocus = false,
  }) async {
    final previous = _manager.focusUserId;
    await _ensureFocusActive(focusUserId);
    try {
      return await operation();
    } finally {
      if (restorePreviousFocus &&
          previous != null &&
          previous != focusUserId &&
          !_blocksSwitchTo(previous)) {
        await _manager._executeFocus(previous);
      }
    }
  }

  /// Prepara archive_user per RPC/upload senza eseguire operazione.
  Future<bool> ensureFocusReady(String focusUserId) async {
    try {
      await _ensureFocusActive(focusUserId);
      return _manager.isSessionReadyForAccount(focusUserId);
    } catch (_) {
      return false;
    }
  }

  IdentityLease acquireLease(
    String focusUserId,
    IdentityLeaseReason reason,
  ) {
    final lease = IdentityLease(
      id: 'lease-${++_leaseCounter}',
      focusUserId: focusUserId,
      reason: reason,
    );
    _leases.add(lease);
    return lease;
  }

  void releaseLease(IdentityLease lease) {
    _leases.removeWhere((entry) => entry.id == lease.id);
  }

  /// Esegue [action] sotto lease — sostituisce [PushMediaSyncGuard.run].
  Future<T> runWithLease<T>(
    String focusUserId,
    IdentityLeaseReason reason,
    Future<T> Function() action,
  ) async {
    final lease = acquireLease(focusUserId, reason);
    try {
      return await action();
    } finally {
      releaseLease(lease);
    }
  }

  /// Gate policy sync push — invarianti notifications §6–8.
  AuthorizePushSyncResult authorizePushSync({
    required PushSyncScope scope,
    required PushSyncReason reason,
  }) {
    if (hasActiveLease) {
      return const AuthorizePushSyncResult(
        authorized: false,
        deferred: true,
      );
    }
    if (reason == PushSyncReason.appResumed &&
        scope == PushSyncScope.allOpenAccounts) {
      return const AuthorizePushSyncResult(
        authorized: false,
        deferred: false,
      );
    }
    return const AuthorizePushSyncResult(
      authorized: true,
      deferred: false,
    );
  }

  /// Valuta policy e, se autorizzato, esegue [sync].
  Future<void> authorizeAndSyncPush({
    required PushSyncScope scope,
    required PushSyncReason reason,
    required Future<void> Function() sync,
  }) async {
    final decision = authorizePushSync(scope: scope, reason: reason);
    if (!decision.authorized) return;
    await sync();
  }

  Future<void> reconnectActiveFocus(String focusUserId) {
    return _manager._reconnectFocusedSession(focusUserId);
  }

  bool _blocksSwitchTo(String userId) {
    if (!hasActiveLease) return false;
    final leaseFocus = leaseFocusUserId;
    return leaseFocus != null && leaseFocus != userId;
  }

  Future<void> _ensureFocusActive(String focusUserId) async {
    if (!_manager.hasOpenAccount(focusUserId)) {
      throw StateError('Account not open: $focusUserId');
    }
    if (_blocksSwitchTo(focusUserId)) {
      throw StateError(
        'Identity switch deferred: lease active for ${leaseFocusUserId!}',
      );
    }
    if (_manager.focusUserId != focusUserId) {
      await _manager._executeFocus(focusUserId);
    } else {
      await _manager._consolidateSessionForAccount(focusUserId);
    }
  }
}
