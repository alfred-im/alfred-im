// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/wiring_test_fixtures.dart';

/// Wiring: AuthController.openConversationFromShareableLink → ExternalIntentAdapter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shareable-link wiring', () {
    const accountId = 'account-a';
    const linkPeerId = 'link-peer-z';

    test('openConversationFromShareableLink apre peer linkato', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();
      final manager = AccountManager(storage: storage);

      final session = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: accountId,
          username: 'agent_a', address: 'agent_a',
          displayName: 'Agent A',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(
          peers: [
            inboxPeer(
              const ProfileSummary(
                id: linkPeerId,
                username: 'link_z',
                address: 'link_z',
                displayName: 'Link Z',
              ),
            ),
          ],
        ),
        profileService: MapBackedFakeProfileService.fromProfiles([
          const ProfileSummary(
            id: linkPeerId,
            username: 'link_z',
            address: 'link_z',
            displayName: 'Link Z',
          ),
        ]),
      );
      session.wireStorage(storage);
      await session.persistOpenAccount(refreshToken: 'refresh-a');
      await storage.saveFocusUserId(accountId);
      manager.restoreSessionForTest = (_) async => session;

      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      final ok = await auth.openConversationFromShareableLink(
        accountUserId: accountId,
        peerAddress: 'link_z',
      );

      expect(ok, isTrue);
      expect(auth.activePeer?.peerAddress, 'link_z');
    });

    test('peer irrisolvibile lascia inbox senza chat aperta', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();
      final manager = AccountManager(storage: storage);

      final session = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: accountId,
          username: 'agent_a', address: 'agent_a',
          displayName: 'Agent A',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
        profileService: MapBackedFakeProfileService({}),
      );
      session.wireStorage(storage);
      await session.persistOpenAccount(refreshToken: 'refresh-a');
      await storage.saveFocusUserId(accountId);
      manager.restoreSessionForTest = (_) async => session;

      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      final ok = await auth.openConversationOnAccount(
        accountUserId: accountId,
        peerAddress: 'unknown-peer',
        allowProfileFallback: false,
      );

      expect(ok, isFalse);
      expect(auth.activePeer, isNull);
    });
  });
}
