// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/open_account.dart';
import '../models/push_sync_scope.dart';
import 'account_session.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

/// Registra subscription Web Push per account nel manifest.
class PushSubscriptionService {
  PushSubscriptionService();

  static Future<void>? _syncInFlight;

  Future<void> syncOpenAccounts(
    List<OpenAccount> accounts, {
    required PushSyncScope scope,
    AccountSession? focusedSession,
    String? newAccountUserId,
  }) async {
    if (!kIsWeb) return;
    if (accounts.isEmpty) return;

    while (_syncInFlight != null) {
      await _syncInFlight;
    }

    final gate = Completer<void>();
    _syncInFlight = gate.future;
    try {
      await _syncOpenAccountsImpl(
        accounts,
        scope: scope,
        focusedSession: focusedSession,
        newAccountUserId: newAccountUserId,
      );
    } finally {
      gate.complete();
      if (identical(_syncInFlight, gate.future)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _syncOpenAccountsImpl(
    List<OpenAccount> accounts, {
    required PushSyncScope scope,
    AccountSession? focusedSession,
    String? newAccountUserId,
  }) async {
    if (!kIsWeb) return;
    if (accounts.isEmpty) return;

    PushPlatform.ensureMessageHook();

    final keys = await PushPlatform.ensureSubscription(
      vapidPublicKey: AppConfig.vapidPublicKey,
    );
    if (keys == null ||
        !shouldPersistPushSubscription(
          notificationPermission: PushPlatform.notificationPermission,
        )) {
      return;
    }

    final deviceId = await PushPlatform.getOrCreateDeviceId();
    final userAgent = defaultTargetPlatform.name;

    final targets = _targetsForScope(
      accounts: accounts,
      scope: scope,
      focusedSession: focusedSession,
      newAccountUserId: newAccountUserId,
    );
    if (targets.isEmpty) return;

    for (final account in targets) {
      if (account.refreshToken.isEmpty) continue;
      if (focusedSession != null && focusedSession.userId == account.userId) {
        final ok = await _upsertWithClient(
          client: focusedSession.client,
          account: account,
          deviceId: deviceId,
          keys: keys,
          userAgent: userAgent,
        );
        if (!ok) {
          await _upsertWithEphemeralClient(
            account: account,
            deviceId: deviceId,
            keys: keys,
            userAgent: userAgent,
          );
        }
        continue;
      }
      await _upsertWithEphemeralClient(
        account: account,
        deviceId: deviceId,
        keys: keys,
        userAgent: userAgent,
      );
    }
  }

  @visibleForTesting
  static List<OpenAccount> targetsForScope({
    required List<OpenAccount> accounts,
    required PushSyncScope scope,
    AccountSession? focusedSession,
    String? newAccountUserId,
  }) {
    switch (scope) {
      case PushSyncScope.allOpenAccounts:
        return List<OpenAccount>.from(accounts);
      case PushSyncScope.focusedAccount:
        final focusId = focusedSession?.userId;
        if (focusId == null) return const [];
        return accounts
            .where((account) => account.userId == focusId)
            .toList(growable: false);
      case PushSyncScope.newAccount:
        final userId = newAccountUserId ?? focusedSession?.userId;
        if (userId == null) return const [];
        return accounts
            .where((account) => account.userId == userId)
            .toList(growable: false);
    }
  }

  List<OpenAccount> _targetsForScope({
    required List<OpenAccount> accounts,
    required PushSyncScope scope,
    AccountSession? focusedSession,
    String? newAccountUserId,
  }) {
    return PushSubscriptionService.targetsForScope(
      accounts: accounts,
      scope: scope,
      focusedSession: focusedSession,
      newAccountUserId: newAccountUserId,
    );
  }

  Future<void> unregisterAccount({
    required String userId,
    required OpenAccount? account,
    required bool isLastAccountOnDevice,
  }) async {
    if (!kIsWeb) return;

    final deviceId = await PushPlatform.getOrCreateDeviceId();
    if (account != null && account.refreshToken.isNotEmpty) {
      await _deleteSubscriptionWithEphemeralClient(
        userId: userId,
        account: account,
        deviceId: deviceId,
      );
    }

    if (isLastAccountOnDevice) {
      await PushPlatform.unregisterServiceWorkerSubscription();
    }
  }

  Future<bool> _upsertWithClient({
    required SupabaseClient client,
    required OpenAccount account,
    required String deviceId,
    required PushSubscriptionKeys keys,
    required String userAgent,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await client.from('push_subscriptions').upsert({
        'user_id': account.userId,
        'device_id': deviceId,
        'endpoint': keys.endpoint,
        'p256dh_key': keys.p256dhKey,
        'auth_key': keys.authKey,
        'user_agent': userAgent,
        'last_seen_at': now,
      }, onConflict: 'user_id,device_id');
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          'push_subscriptions upsert failed for ${account.userId}: $e\n$stack',
        );
      }
      return false;
    }
  }

  /// Auth effimera — non tocca sessione in focus né `AccountSession.restore`.
  Future<void> _upsertWithEphemeralClient({
    required OpenAccount account,
    required String deviceId,
    required PushSubscriptionKeys keys,
    required String userAgent,
  }) async {
    if (account.refreshToken.isEmpty) return;

    final client = AccountSession.createBootstrapClient();
    try {
      await client.auth.setSession(account.refreshToken);
      if (client.auth.currentUser == null) return;
      await _upsertWithClient(
        client: client,
        account: account,
        deviceId: deviceId,
        keys: keys,
        userAgent: userAgent,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          'push_subscriptions ephemeral upsert failed for ${account.userId}: $e\n$stack',
        );
      }
    }
  }

  Future<void> _deleteSubscriptionWithEphemeralClient({
    required String userId,
    required OpenAccount account,
    required String deviceId,
  }) async {
    final client = AccountSession.createBootstrapClient();
    try {
      await client.auth.setSession(account.refreshToken);
      if (client.auth.currentUser == null) return;
      await client.from('push_subscriptions').delete().match({
        'user_id': userId,
        'device_id': deviceId,
      });
    } catch (_) {
      // Best-effort: account may already be logged out locally.
    }
  }
}
