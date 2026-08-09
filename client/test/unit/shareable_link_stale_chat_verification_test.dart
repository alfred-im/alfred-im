// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/coordinators/navigation_coordinator.dart';

import '../support/open_conversation_stale_harness.dart';

/// Link shareable — dominio navigation/invariants.md § No stale chat
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shareable link open conversation stale', () {
    const accountId = 'account-a';
    const stalePeerId = 'stale-peer-y';
    const linkPeerId = 'link-peer-z';

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
            OpenConversationStaleHarness.profile(linkPeerId, 'link_z'),
          ),
        ],
        peersById: {
          linkPeerId: OpenConversationStaleHarness.profile(linkPeerId, 'link_z'),
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
        peerProfileId: linkPeerId,
      );

      expect(ok, isTrue);
      expect(manager.viewState.activePeer?.profileId, linkPeerId);
    });

    test('fallback profilo se assente da inbox', () async {
      final session = await OpenConversationStaleHarness.session(
        accountId: accountId,
        username: 'agent_a',
        peersById: {
          linkPeerId: OpenConversationStaleHarness.profile(linkPeerId, 'link_z'),
        },
      );
      manager.injectTestSession(session);

      final ok = await nav.openConversationOnAccount(
        accountUserId: accountId,
        peerProfileId: linkPeerId,
      );

      expect(ok, isTrue);
      expect(manager.viewState.activePeer?.profileId, linkPeerId);
    });
  });
}
