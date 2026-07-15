// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/open_account.dart';
import 'account_session.dart';
import '../utils/push_permission_flow.dart';
import '../utils/push_platform.dart';

/// Registra subscription Web Push per tutti gli account nel manifest.
class PushSubscriptionService {
  PushSubscriptionService();

  static Future<void>? _syncInFlight;

  Future<void> syncOpenAccounts(
    List<OpenAccount> accounts, {
    AccountSession? focusedSession,
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
        focusedSession: focusedSession,
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
    AccountSession? focusedSession,
  }) async {
    if (!kIsWeb) return;
    if (accounts.isEmpty) return;

    PushPlatform.ensureMessageHook();

    if (!shouldAttemptPushSubscription(
      isPushSupported: PushPlatform.isPushSupported,
      notificationPermission: PushPlatform.notificationPermission,
    )) {
      return;
    }

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

    for (final account in accounts) {
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
          await _upsertForAccount(
            account: account,
            deviceId: deviceId,
            keys: keys,
            userAgent: userAgent,
          );
        }
        continue;
      }
      await _upsertForAccount(
        account: account,
        deviceId: deviceId,
        keys: keys,
        userAgent: userAgent,
      );
    }
  }

  Future<void> unregisterAccount({
    required String userId,
    required OpenAccount? account,
    required bool isLastAccountOnDevice,
  }) async {
    if (!kIsWeb) return;

    final deviceId = await PushPlatform.getOrCreateDeviceId();
    AccountSession? session;
    try {
      if (account != null && account.refreshToken.isNotEmpty) {
        session = await AccountSession.restore(account, skipHydrate: true);
        await session.client.from('push_subscriptions').delete().match({
          'user_id': userId,
          'device_id': deviceId,
        });
      }
    } catch (_) {
      // Best-effort: account may already be logged out locally.
    } finally {
      await session?.disposeResources(clearAuthStorage: false);
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

  Future<void> _upsertForAccount({
    required OpenAccount account,
    required String deviceId,
    required PushSubscriptionKeys keys,
    required String userAgent,
  }) async {
    AccountSession? session;
    try {
      session = await AccountSession.restore(account, skipHydrate: true);
      final now = DateTime.now().toUtc().toIso8601String();
      await session.client.from('push_subscriptions').upsert({
        'user_id': account.userId,
        'device_id': deviceId,
        'endpoint': keys.endpoint,
        'p256dh_key': keys.p256dhKey,
        'auth_key': keys.authKey,
        'user_agent': userAgent,
        'last_seen_at': now,
      }, onConflict: 'user_id,device_id');
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          'push_subscriptions upsert failed for ${account.userId}: $e\n$stack',
        );
      }
    } finally {
      await session?.disposeResources(clearAuthStorage: false);
    }
  }
}
