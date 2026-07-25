// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/machines/navigation/navigation_machine.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_storage_service.dart';

import '../support/wiring_test_fixtures.dart';

ChatPeer _peer(String id, String username) => ChatPeer.fromProfile(
      profile: ProfileSummary(
        id: id,
        username: username,
        displayName: username,
      ),
    );

/// Wiring: ExternalIntentAdapter → NavigationCoordinator → AccountNavigationEffects
/// (effects live) + MultiAccountAdapters focus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('navigation wiring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('openPeerOnFocusedAccount via coordinator production stack', () async {
      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: 'account-a', username: 'alice'),
        ],
        focusUserId: 'account-a',
      );

      final auth = await createWiredAuthController(
        manager: AccountManager(storage: storage),
      );
      await auth.initialize();

      await auth.navigation.openPeerOnFocusedAccount(_peer('peer-b', 'bob'));

      expect(auth.navigation.machine.shellState, NavigationShellState.chatOpen);
      expect(auth.viewState.activePeer?.profileId, 'peer-b');
    });

    test('externalIntents.openFromCompose attraversa adapter unificato', () async {
      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: 'account-a', username: 'alice'),
        ],
        focusUserId: 'account-a',
      );

      final auth = await createWiredAuthController(
        manager: AccountManager(storage: storage),
      );
      await auth.initialize();

      final ok = await auth.externalIntents.openFromCompose(
        accountUserId: 'account-a',
        peerProfileId: 'peer-c',
        allowProfileFallback: false,
      );

      expect(ok, isFalse);
      expect(auth.navigation.machine.shellState,
          NavigationShellState.inboxVisible);
    });
  });
}
