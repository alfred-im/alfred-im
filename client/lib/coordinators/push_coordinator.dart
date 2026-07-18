// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../machines/notifications/notifications_machine.dart';
import '../models/open_account.dart';
import '../services/account_manager.dart';
import '../services/push_subscription_service.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

/// Orchestrazione push: permessi, macchina notifications, sync subscription.
class PushCoordinator {
  PushCoordinator({
    required this._manager,
    required this._notificationsMachine,
    PushSubscriptionService? pushService,
  }) : _pushService = pushService ?? PushSubscriptionService();

  final AccountManager _manager;
  final NotificationsMachine _notificationsMachine;
  final PushSubscriptionService _pushService;

  NotificationsMachine get notificationsMachine => _notificationsMachine;

  /// Re-registra subscription push (es. dopo resume PWA o permesso concesso).
  Future<void> syncPushSubscriptions() async {
    if (kIsWeb) {
      _applyPushEnvironmentToMachine();
      if (!shouldAttemptPushSubscription(
        isPushSupported: PushPlatform.isPushSupported,
        notificationPermission: PushPlatform.notificationPermission,
      )) {
        return;
      }
    }

    _notificationsMachine.send(const SyncSubscriptionsRequested());
    try {
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        focusedSession: _manager.focusedSession,
      );
      _notificationsMachine.send(const SubscriptionRegistered());
    } catch (_) {
      _notificationsMachine.send(const SubscriptionSyncFailed());
    }
  }

  Future<void> syncAfterAuth() {
    return _pushService.syncOpenAccounts(
      _manager.openAccounts,
      focusedSession: _manager.focusedSession,
    );
  }

  Future<void> unregisterAccount({
    required String userId,
    required OpenAccount? account,
    required bool isLastAccountOnDevice,
  }) {
    _notificationsMachine.send(const UnregisterSubscriptionRequested());
    return _pushService.unregisterAccount(
      userId: userId,
      account: account,
      isLastAccountOnDevice: isLastAccountOnDevice,
    );
  }

  void _applyPushEnvironmentToMachine() {
    if (!PushPlatform.isPushSupported) {
      _notificationsMachine.send(const PushUnsupportedDetected());
    } else if (PushPlatform.notificationPermission == 'denied') {
      _notificationsMachine.send(const PermissionDeniedDetected());
    } else {
      _notificationsMachine.send(const SubscriptionIdleReached());
    }
  }
}
