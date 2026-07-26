// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/utils/messaging_session_identity.dart';

import '../support/fake_messaging_services.dart';

void main() {
  group('messaging_session_identity', () {
    test('allineato quando auth.uid = owner e peer distinto', () async {
      final client = createTestSupabaseClient();
      await installTestAuthSession(client, userId: 'owner-a');

      expect(
        isMessagingIdentityAligned(
          client: client,
          ownerUserId: 'owner-a',
          peerProfileId: 'peer-b',
        ),
        isTrue,
      );
    });

    test('non allineato quando auth.uid = peer (scenario Aga1→test2)', () async {
      final client = createTestSupabaseClient();
      await installTestAuthSession(client, userId: 'peer-b');

      expect(
        isMessagingIdentityAligned(
          client: client,
          ownerUserId: 'owner-a',
          peerProfileId: 'peer-b',
        ),
        isFalse,
      );
    });

    test('friendlyMessagingError nasconde PostgrestException cannot message yourself', () {
      expect(
        friendlyMessagingError(
          const PostgrestException(
            message: 'cannot message yourself',
            code: 'P0001',
          ),
        ),
        messagingSessionExpiredMessage,
      );
    });
  });
}
