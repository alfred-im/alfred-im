// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../machines/notifications/notifications_adapters.dart';
import '../machines/notifications/notifications_machine.dart';
import '../models/open_account.dart';
import '../models/push_sync_scope.dart';
import '../services/account_manager.dart';
import '../services/push_subscription_service.dart';
import '../utils/push_media_sync_guard.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

/// Orchestrazione push: permessi, macchina notifications, sync subscription.
class PushCoordinator {
  PushCoordinator({
    required this._manager,
    required this._notificationsAdapters,
    this._notificationsMachine,
    PushSubscriptionService? pushService,
  }) : _pushService = pushService ?? PushSubscriptionService();

  final AccountManager _manager;
  final NotificationsAdapters _notificationsAdapters;
  final NotificationsMachine? _notificationsMachine;
  final PushSubscriptionService _pushService;

  NotificationsMachine? get notificationsMachine => _notificationsMachine;

  /// Re-registra subscription push secondo [scope] e [reason] espliciti.
  Future<void> syncPushSubscriptions({
    required PushSyncScope scope,
    required PushSyncReason reason,
    String? newAccountUserId,
  }) async {
    if (PushMediaSyncGuard.isActive) {
      return;
    }

    if (kIsWeb) {
      _notificationsAdapters.onPushSupportChecked(
        supported: PushPlatform.isPushSupported,
        permission: PushPlatform.notificationPermission,
      );
      if (!shouldAttemptPushSubscription(
        isPushSupported: PushPlatform.isPushSupported,
        notificationPermission: PushPlatform.notificationPermission,
      )) {
        return;
      }
    }

    _notificationsAdapters.onSyncSubscriptionsRequested();
    try {
      await _pushService.syncOpenAccounts(
        _manager.openAccounts,
        scope: scope,
        focusedSession: _manager.focusedSession,
        newAccountUserId: newAccountUserId ?? _resolveNewAccountUserId(reason),
      );
      _notificationsAdapters.onPushRegistrationSucceeded();
    } catch (_) {
      _notificationsAdapters.onPushRegistrationFailed();
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
    _notificationsAdapters.onUnregisterSubscription();
    return _pushService.unregisterAccount(
      userId: userId,
      account: account,
      isLastAccountOnDevice: isLastAccountOnDevice,
    );
  }
}
