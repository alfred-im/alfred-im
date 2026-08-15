// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/models/push_sync_scope.dart';
import 'package:alfred_client/utils/push_media_sync_guard.dart';

void main() {
  group('SessionAuthority', () {
    late AccountManager manager;
    late SessionAuthority authority;

    setUp(() {
      manager = AccountManager();
      authority = manager.sessionAuthority;
    });

    test('identityGeneration follows focused session epoch', () {
      expect(authority.identityGeneration, 0);
    });

    test('acquireLease blocks switch to other focus', () async {
      final lease = authority.acquireLease('account-a', IdentityLeaseReason.mediaUpload);
      expect(authority.hasActiveLease, isTrue);
      expect(
        () => authority.requestFocusSwitch('account-b'),
        throwsStateError,
      );
      authority.releaseLease(lease);
      expect(authority.hasActiveLease, isFalse);
    });

    test('nested leases release correctly', () {
      final a = authority.acquireLease('account-a', IdentityLeaseReason.mediaPicker);
      final b = authority.acquireLease('account-a', IdentityLeaseReason.mediaUpload);
      expect(authority.hasActiveLease, isTrue);
      authority.releaseLease(a);
      expect(authority.hasActiveLease, isTrue);
      authority.releaseLease(b);
      expect(authority.hasActiveLease, isFalse);
    });

    group('authorizePushSync', () {
      test('defers when lease active', () {
        final lease = authority.acquireLease(
          'account-a',
          IdentityLeaseReason.mediaPicker,
        );
        addTearDown(() => authority.releaseLease(lease));

        final result = authority.authorizePushSync(
          scope: PushSyncScope.focusedAccount,
          reason: PushSyncReason.appResumed,
        );
        expect(result.deferred, isTrue);
        expect(result.authorized, isFalse);
      });

      test('blocks AllOpenAccounts on app resume', () {
        final result = authority.authorizePushSync(
          scope: PushSyncScope.allOpenAccounts,
          reason: PushSyncReason.appResumed,
        );
        expect(result.authorized, isFalse);
        expect(result.deferred, isFalse);
      });

      test('allows focused account on resume without lease', () {
        final result = authority.authorizePushSync(
          scope: PushSyncScope.focusedAccount,
          reason: PushSyncReason.appResumed,
        );
        expect(result.authorized, isTrue);
        expect(result.deferred, isFalse);
      });
    });

    group('PushMediaSyncGuard', () {
      test('delegates to SessionAuthority when bound', () async {
        PushMediaSyncGuard.bind(authority);
        expect(PushMediaSyncGuard.isActive, isFalse);
        await PushMediaSyncGuard.run(() async {
          expect(PushMediaSyncGuard.isActive, isTrue);
        }, recipientUserId: 'account-a');
        expect(PushMediaSyncGuard.isActive, isFalse);
      });
    });
  });
}
