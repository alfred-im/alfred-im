// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/push_sync_scope.dart';
import 'package:alfred_client/services/push_subscription_service.dart';
import 'package:alfred_client/utils/push_permission_flow.dart';
import 'package:alfred_client/utils/push_stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('syncOpenAccounts is no-op off-web', () async {
    final service = PushSubscriptionService();
    await service.syncOpenAccounts(
      const [],
      scope: PushSyncScope.allOpenAccounts,
    );
    await service.unregisterAccount(
      userId: 'x',
      account: null,
      isLastAccountOnDevice: true,
    );
    expect(await PushPlatform.getOrCreateDeviceId(), isNotEmpty);
  });

  test('off-web push is not supported', () {
    expect(PushPlatform.isPushSupported, isFalse);
    expect(PushPlatform.notificationPermission, isNull);
  });

  test('service skips sync when push unsupported', () async {
    expect(
      shouldAttemptPushSubscription(
        isPushSupported: PushPlatform.isPushSupported,
        notificationPermission: PushPlatform.notificationPermission,
      ),
      isFalse,
    );
  });
}
