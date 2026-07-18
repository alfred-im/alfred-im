// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';

import '../support/fake_messaging_services.dart';

ChatPeer _peer(String id) {
  return ChatPeer(
    profile: ProfileSummary(id: id, displayName: 'Peer $id'),
    preview: 'ciao',
    lastMessageAt: DateTime.utc(2026, 6, 29),
  );
}

Future<AccountSession> _session(String id) {
  return AccountSession.createForTest(
    profile: ProfileSummary(id: id, username: id, displayName: id),
    client: createTestSupabaseClient(),
    inboxService: FakeInboxService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // spec: PROM-MULTI-ACCOUNT-010
  group('AccountManager per-account view state (via navigation)', () {
    late AccountManager manager;
    late NavigationCoordinator nav;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      nav = NavigationCoordinator(manager);
    });

    test('openConversation and setFocus preserve view per account', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');
      manager.injectTestSession(await _session('account-a'));
      manager.injectTestSession(await _session('account-b'));

      await manager.setFocus('account-a');
      nav.openPeerOnFocusedAccount(_peer('account-b'));

      await manager.setFocus('account-b');
      nav.openPeerOnFocusedAccount(_peer('account-a'));

      await manager.setFocus('account-a');
      expect(manager.viewState.activePeer?.profileId, 'account-b');

      await manager.setFocus('account-b');
      expect(manager.viewState.activePeer?.profileId, 'account-a');
    });

    test('setFocus does not clear other accounts view state', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');
      manager.injectTestSession(await _session('account-a'));
      manager.injectTestSession(await _session('account-b'));

      await manager.setFocus('account-a');
      nav.openPeerOnFocusedAccount(_peer('account-b'));

      await manager.setFocus('account-b');
      expect(manager.viewState.activePeer, isNull);

      await manager.setFocus('account-a');
      expect(manager.viewState.activePeer?.profileId, 'account-b');
    });

    test('removeAccount drops saved view for that user', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');
      manager.injectTestSession(await _session('account-a'));
      manager.injectTestSession(await _session('account-b'));

      await manager.setFocus('account-a');
      nav.openPeerOnFocusedAccount(_peer('account-b'));

      await manager.removeAccount('account-a');
      await manager.setFocus('account-b');

      expect(manager.viewState.activePeer, isNull);
    });
  });
}
