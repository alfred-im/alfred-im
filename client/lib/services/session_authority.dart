// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/push_sync_scope.dart';
import 'account_manager.dart';
import 'account_session.dart';

/// Motivo di un lease identità — vedi docs/domain/multi-account/session-authority.md.
enum IdentityLeaseReason {
  mediaUpload,
  mediaPicker,
  other,
}

/// Lease che blocca switch verso altro owner durante operazioni lunghe.
class IdentityLease {
  const IdentityLease({
    required this.id,
    required this.ownerUserId,
    required this.reason,
  });

  final String id;
  final String ownerUserId;
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

  /// Owner con JWT attivo in RAM (null se nessuna sessione).
  String? get activeOwnerId => _manager.focusUserId;

  AccountSession? get focusedSession => _manager.focusedSession;

  /// Generazione identità — allineata a [AccountSession.epoch] della sessione attiva.
  int get identityGeneration => _manager.focusedSession?.epoch ?? 0;

  bool get hasActiveLease => _leases.isNotEmpty;

  String? get leaseOwnerUserId =>
      _leases.isEmpty ? null : _leases.first.ownerUserId;

  /// Serializza dispose + restore per cambio focus UI.
  Future<void> requestFocusSwitch(
    String userId, {
    bool deferProfileSync = false,
    VoidCallback? onFocusIdentityChanged,
  }) async {
    if (_blocksSwitchTo(userId)) {
      throw StateError(
        'Identity switch deferred: lease active for ${leaseOwnerUserId!}',
      );
    }
    await _manager.executeFocus(
      userId,
      deferProfileSync: deferProfileSync,
      onFocusIdentityChanged: onFocusIdentityChanged,
    );
  }

  /// Garantisce JWT per [ownerUserId] prima di [operation].
  Future<T> runAsOwner<T>(
    String ownerUserId,
    Future<T> Function() operation, {
    bool restorePreviousOwner = false,
  }) async {
    final previous = _manager.focusUserId;
    await _ensureOwnerActive(ownerUserId);
    try {
      return await operation();
    } finally {
      if (restorePreviousOwner &&
          previous != null &&
          previous != ownerUserId &&
          !_blocksSwitchTo(previous)) {
        await _manager.executeFocus(previous);
      }
    }
  }

  /// Prepara owner per RPC/upload senza eseguire operazione.
  Future<bool> ensureOwnerReady(String ownerUserId) async {
    try {
      await _ensureOwnerActive(ownerUserId);
      return _manager.isSessionReadyForAccount(ownerUserId);
    } catch (_) {
      return false;
    }
  }

  IdentityLease acquireLease(
    String ownerUserId,
    IdentityLeaseReason reason,
  ) {
    final lease = IdentityLease(
      id: 'lease-${++_leaseCounter}',
      ownerUserId: ownerUserId,
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
    String ownerUserId,
    IdentityLeaseReason reason,
    Future<T> Function() action,
  ) async {
    final lease = acquireLease(ownerUserId, reason);
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

  Future<void> reconnectActiveOwner(String focusUserId) {
    return _manager.reconnectFocusedSession(focusUserId);
  }

  bool _blocksSwitchTo(String userId) {
    if (!hasActiveLease) return false;
    final leaseOwner = leaseOwnerUserId;
    return leaseOwner != null && leaseOwner != userId;
  }

  Future<void> _ensureOwnerActive(String ownerUserId) async {
    if (!_manager.hasOpenAccount(ownerUserId)) {
      throw StateError('Account not open: $ownerUserId');
    }
    if (_blocksSwitchTo(ownerUserId)) {
      throw StateError(
        'Identity switch deferred: lease active for ${leaseOwnerUserId!}',
      );
    }
    if (_manager.focusUserId != ownerUserId) {
      await _manager.executeFocus(ownerUserId);
    } else {
      await _manager.consolidateSessionForAccount(ownerUserId);
    }
  }
}
