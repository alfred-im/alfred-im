// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/open_account.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/push_sync_scope.dart';
import 'package:alfred_client/services/push_subscription_service.dart';
import 'package:alfred_client/utils/push_media_sync_guard.dart';
import 'package:alfred_client/utils/push_permission_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushSubscriptionService.targetsForScope', () {
    final accounts = [
      const OpenAccount(
        profile: ProfileSummary(
          id: 'a',
          username: 'a',
          displayName: 'A',
        ),
        refreshToken: 'ra',
      ),
      const OpenAccount(
        profile: ProfileSummary(
          id: 'b',
          username: 'b',
          displayName: 'B',
        ),
        refreshToken: 'rb',
      ),
    ];

    test('allOpenAccounts returns every manifest entry', () {
      expect(
        PushSubscriptionService.targetsForScope(
          accounts: accounts,
          scope: PushSyncScope.allOpenAccounts,
        ),
        accounts,
      );
    });

    test('focusedAccount returns only focused user', () {
      expect(
        PushSubscriptionService.targetsForScope(
          accounts: accounts,
          scope: PushSyncScope.focusedAccount,
          focusedSession: null,
          newAccountUserId: 'b',
        ),
        isEmpty,
      );
    });

    test('newAccount returns target user only', () {
      final targets = PushSubscriptionService.targetsForScope(
        accounts: accounts,
        scope: PushSyncScope.newAccount,
        newAccountUserId: 'b',
      );
      expect(targets.length, 1);
      expect(targets.single.userId, 'b');
    });
  });

  group('notificationPermissionJustGranted', () {
    test('detects transition to granted', () {
      expect(
        notificationPermissionJustGranted(previous: 'default', current: 'granted'),
        isTrue,
      );
      expect(
        notificationPermissionJustGranted(previous: 'denied', current: 'granted'),
        isTrue,
      );
      expect(
        notificationPermissionJustGranted(previous: 'granted', current: 'granted'),
        isFalse,
      );
    });
  });

  group('PushMediaSyncGuard', () {
    test('tracks nested picker sessions', () async {
      expect(PushMediaSyncGuard.isActive, isFalse);
      await PushMediaSyncGuard.run(() async {
        expect(PushMediaSyncGuard.isActive, isTrue);
        await PushMediaSyncGuard.run(() async {
          expect(PushMediaSyncGuard.isActive, isTrue);
        });
        expect(PushMediaSyncGuard.isActive, isTrue);
      });
      expect(PushMediaSyncGuard.isActive, isFalse);
    });
  });
}
