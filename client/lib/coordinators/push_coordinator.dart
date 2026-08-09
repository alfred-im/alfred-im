// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../models/open_account.dart';
import '../models/push_sync_scope.dart';
import '../services/account_manager.dart';
import '../services/push_subscription_service.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

/// Orchestrazione push: permessi e sync subscription.
class PushCoordinator {
  PushCoordinator({
    required this._manager,
    PushSubscriptionService? pushService,
    SessionAuthority? sessionAuthority,
  })  : _authority = sessionAuthority ?? _manager.sessionAuthority,
        _pushService = pushService ?? PushSubscriptionService();

  final AccountManager _manager;
  final SessionAuthority _authority;
  final PushSubscriptionService _pushService;

  /// Re-registra subscription push secondo [scope] e [reason] espliciti.
  Future<void> syncPushSubscriptions({
    required PushSyncScope scope,
    required PushSyncReason reason,
    String? newAccountUserId,
  }) async {
    final decision = _authority.authorizePushSync(
      scope: scope,
      reason: reason,
    );
    if (decision.deferred) {
      return;
    }
    if (!decision.authorized) return;

    if (kIsWeb) {
      if (!shouldAttemptPushSubscription(
        isPushSupported: PushPlatform.isPushSupported,
        notificationPermission: PushPlatform.notificationPermission,
      )) {
        return;
      }
    }

    try {
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        scope: scope,
        focusedSession: _manager.focusedSession,
        newAccountUserId: newAccountUserId ?? _resolveNewAccountUserId(reason),
      );
    } catch (_) {
      // Sync fallita — nessuno stato subscription esposto alla UI.
    }
  }

  String? _resolveNewAccountUserId(PushSyncReason reason) {
    if (reason != PushSyncReason.accountOpened) return null;
    return _manager.focusUserId;
  }

  Future<void> unregisterAccount({
    required String userId,
    required OpenAccount? account,
    required bool isLastAccountOnDevice,
  }) {
    return _pushService.unregisterAccount(
      userId: userId,
      account: account,
      isLastAccountOnDevice: isLastAccountOnDevice,
    );
  }
}
