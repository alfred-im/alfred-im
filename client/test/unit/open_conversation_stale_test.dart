// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';

import '../support/open_conversation_stale_harness.dart';

/// open_conversation_stale_test — dominio navigation/invariants.md § No stale chat
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('open conversation stale', () {
    const accountId = 'account-a';
    const stalePeerId = 'stale-peer-y';
    const targetPeerId = 'target-peer-z';

    late AccountManager manager;
    late NavigationCoordinator nav;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      nav = NavigationCoordinator(manager);

      final session = await OpenConversationStaleHarness.session(
        accountId: accountId,
        username: 'agent_a',
        inboxPeers: [
          OpenConversationStaleHarness.peer(
            OpenConversationStaleHarness.profile(targetPeerId, 'target_z'),
          ),
        ],
        peersById: {
          targetPeerId: OpenConversationStaleHarness.profile(targetPeerId, 'target_z'),
        },
      );
      manager.focusTestSession(session);
      OpenConversationStaleHarness.seedStaleChat(
        manager: manager,
        accountId: accountId,
        stalePeerId: stalePeerId,
        staleUsername: 'stale_y',
      );
    });

    test('openConversationOnAccount sostituisce chat stale', () async {
      final ok = await nav.openConversationOnAccount(
        accountUserId: accountId,
        peerProfileId: targetPeerId,
      );

      expect(ok, isTrue);
      expect(manager.viewState.activePeer?.profileId, targetPeerId);
      expect(manager.viewState.activePeer?.profileId, isNot(stalePeerId));
    });

    test('peer irrisolvibile → inbox senza chat', () async {
      final ok = await nav.openConversationOnAccount(
        accountUserId: accountId,
        peerProfileId: 'unknown-peer',
        allowProfileFallback: false,
      );

      expect(ok, isFalse);
      expect(manager.viewState.activePeer, isNull);
    });
  });
}
