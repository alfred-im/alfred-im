// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/machines/navigation/navigation_machine.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';

import '../support/open_conversation_stale_harness.dart';

/// Tap push — dominio navigation/invariants.md § No stale chat
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('push tap open conversation stale', () {
    const accountA = 'account-a';
    const accountB = 'account-b';
    const stalePeerId = 'stale-peer-y';
    const pushSenderId = 'push-sender-z';

    late AccountManager manager;
    late NavigationCoordinator nav;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      nav = NavigationCoordinator(manager);

      final sessionA = await OpenConversationStaleHarness.session(
        accountId: accountA,
        username: 'agent_a',
      );
      final sessionB = await OpenConversationStaleHarness.session(
        accountId: accountB,
        username: 'agent_b',
        inboxPeers: [
          OpenConversationStaleHarness.peer(
            OpenConversationStaleHarness.profile(pushSenderId, 'sender_z'),
          ),
        ],
        peersById: {
          pushSenderId: OpenConversationStaleHarness.profile(pushSenderId, 'sender_z'),
        },
      );

      manager.seedTestAccount(accountA);
      manager.seedTestAccount(accountB);
      manager.injectTestSession(sessionA);
      manager.injectTestSession(sessionB);
      manager.focusTestSession(sessionA);

      await manager.setFocus(accountB);
      OpenConversationStaleHarness.seedStaleChat(
        manager: manager,
        accountId: accountB,
        stalePeerId: stalePeerId,
        staleUsername: 'stale_y',
      );

      await manager.setFocus(accountA);
    });

    test('openFromPushTap apre mittente su account destinatario', () async {
      final ok = await nav.adapters.openFromPushTap(
        accountUserId: accountB,
        peerProfileId: pushSenderId,
      );

      expect(ok, isTrue);
      expect(manager.focusUserId, accountB);
      expect(manager.viewState.activePeer?.profileId, pushSenderId);
    });

    test('switch focus senza tap non commette scope', () async {
      await nav.switchToAccount(accountB);

      expect(manager.focusUserId, accountB);
      expect(manager.viewState.activePeer?.profileId, stalePeerId);
      expect(nav.committedScope, isNull);
      expect(nav.machine.shellState, NavigationShellState.inboxVisible);
    });
  });
}
