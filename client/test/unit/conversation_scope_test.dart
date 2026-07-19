// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/multi-account/multi_account_adapters.dart';
import 'package:alfred_client/machines/navigation/account_navigation_effects.dart';
import 'package:alfred_client/machines/navigation/navigation_machine.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/models/open_conversation_source.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

class _ImmediateFocus implements AccountFocusCommand {
  _ImmediateFocus(this._manager);

  final AccountManager _manager;

  @override
  Future<void> focusAccount(String accountUserId) async {
    final session = _manager.focusedSession;
    if (session != null && session.userId == accountUserId) return;
  }
}

void main() {
  group('ConversationScope in NavigationMachine', () {
    late AccountManager manager;
    late NavigationCoordinator navigation;
    late AccountSession sessionA;
    late AccountSession sessionA2;
    const peer = ProfileSummary(
      id: 'peer-z',
      username: 'peer_z',
      displayName: 'Peer Z',
    );

    setUp(() async {
      manager = AccountManager();
      navigation = NavigationCoordinator(manager);
      final client = createTestSupabaseClient();
      sessionA = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'user-a',
          username: 'user_a',
          displayName: 'User A',
        ),
        client: client,
        inboxService: FakeInboxService(
          peers: [ChatPeer(profile: peer)],
        ),
        messageService: FakeMessageService(client),
      );
      sessionA2 = await AccountSession.createForTest(
        profile: sessionA.profile,
        client: client,
        inboxService: FakeInboxService(
          peers: [ChatPeer(profile: peer)],
        ),
        messageService: FakeMessageService(client),
      );
      manager.focusTestSession(sessionA);
    });

    test('commitScope registra solo con sessione viva', () {
      final scope = ConversationScope.fromSession(
        sessionA,
        ChatPeer(profile: peer),
      );
      navigation.machine.commitScope(scope);

      expect(navigation.committedScope, scope);
    });

    test('commitScope con sessione assente non registra', () {
      navigation.machine.commitScope(
        ConversationScope.fromSession(sessionA, ChatPeer(profile: peer)),
      );
      manager.clearSessionsInRamForTest();

      navigation.machine.commitScope(
        ConversationScope(
          ownerUserId: 'user-a',
          peerProfileId: 'peer-z',
          sessionEpoch: sessionA.epoch,
        ),
      );

      expect(navigation.committedScope?.sessionEpoch, sessionA.epoch);
    });

    test('restoreCommittedScopeFromViewState riallinea dopo restore', () {
      manager.applyAccountViewState(
        'user-a',
        (view) => view.openChat(ChatPeer(profile: peer)),
      );
      navigation.restoreCommittedScopeAfterFocusSettled();

      expect(navigation.committedScope?.peerProfileId, 'peer-z');
      expect(navigation.committedScope?.sessionEpoch, sessionA.epoch);
    });

    test('invalidateCommittedScope su switch account', () {
      navigation.machine.commitScope(
        ConversationScope.fromSession(sessionA, ChatPeer(profile: peer)),
      );

      navigation.invalidateCommittedScope();
      expect(navigation.committedScope, isNull);
    });

    test('isConversationReady riallinea epoch su sessione ricreata', () {
      navigation.machine.commitScope(
        ConversationScope.fromSession(sessionA, ChatPeer(profile: peer)),
      );

      manager.clearSessionsInRamForTest();
      manager.focusTestSession(sessionA2);

      expect(
        navigation.isConversationReady(
          session: sessionA2,
          peer: ChatPeer(profile: peer),
        ),
        isTrue,
      );
      expect(navigation.committedScope?.sessionEpoch, sessionA2.epoch);
    });

    test('openConversation via effects committa scope su macchina', () async {
      final effects = AccountNavigationEffects(
        manager,
        focusCommand: _ImmediateFocus(manager),
      );
      final machine = NavigationMachine(effects);
      effects.navigationMachine = machine;

      final ok = await effects.openConversation(
        accountUserId: 'user-a',
        peerProfileId: 'peer-z',
        source: OpenConversationSource.inbox,
      );

      expect(ok, isTrue);
      expect(machine.committedScope?.ownerUserId, 'user-a');
      expect(machine.committedScope?.peerProfileId, 'peer-z');
    });
  });
}
