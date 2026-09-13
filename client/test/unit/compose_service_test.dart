// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/services/compose_service.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late ComposeService composeService;

  setUp(() {
    composeService = ComposeService(
      profileService: ProfileService(
        SupabaseClient(
          'http://127.0.0.1',
          'test-anon-key',
          authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            autoRefreshToken: false,
          ),
        ),
      ),
    );
  });

  group('ComposeService.peerFromContact', () {
    test('maps contact address to ChatPeer', () {
      final peer = composeService.peerFromContact(
        Contact(
          id: 'c1',
          archiveUserId: 'alice',
          address: 'peer-1',
          createdAt: DateTime.utc(2026, 6, 28),
        ),
      );

      expect(peer.peerAddress, 'peer-1');
      expect(peer.displayName, 'peer-1');
    });

    test('supports federated address', () {
      final peer = composeService.peerFromContact(
        Contact(
          id: 'c2',
          archiveUserId: 'alice',
          address: 'alice@arkham-im.fly.dev',
          createdAt: DateTime.utc(2026, 6, 28),
        ),
      );

      expect(peer.peerAddress, 'alice@arkham-im.fly.dev');
    });
  });
}
