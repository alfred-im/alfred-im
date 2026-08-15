// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/multi-account/multi_account_adapters.dart';
import 'package:alfred_client/machines/navigation/account_navigation_effects.dart';
import 'package:alfred_client/machines/navigation/navigation_machine.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/open_conversation_source.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/coordinators/navigation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

/// Consolidamento sessione GoTrue all'ingresso chat — vedi dominio navigation/invariants.md
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PROM-CONVERSATION-SCOPE-008 consolidate session', () {
    late AccountStorageService storage;
    late AccountManager manager;
    late AccountSession sessionA;
    late AccountSession sessionB;
    var restoreCallsForA = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
      manager = AccountManager(storage: storage);

      sessionA = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-a',
          username: 'agent_a',
          displayName: 'Agent A',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(
          peers: const [
            ChatPeer(
              profile: ProfileSummary(
                id: 'account-b',
                username: 'agent_b',
                displayName: 'Agent B',
              ),
            ),
          ],
        ),
      );
      await installTestAuthSession(sessionA.client, userId: 'account-a');

      sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'account-b',
          username: 'agent_b',
          displayName: 'Agent B',
        ),
        client: createTestSupabaseClient(),
        inboxService: FakeInboxService(),
      );
      await installTestAuthSession(sessionB.client, userId: 'account-b');

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      restoreCallsForA = 0;
      manager.restoreSessionForTest = (account) async {
        if (account.userId == 'account-a') {
          restoreCallsForA += 1;
          return sessionA;
        }
        return sessionB;
      };

      await manager.initialize(focusUserId: 'account-a');
    });

    group('SessionAuthority.ensureFocusReady', () {
      test('ripristina sessione se JWT assente in RAM', () async {
        manager.clearSessionsInRamForTest();

        await manager.sessionAuthority.ensureFocusReady('account-a');

        expect(restoreCallsForA, greaterThanOrEqualTo(1));
        expect(manager.isSessionReadyForAccount('account-a'), isTrue);
        expect(manager.sessions.map((s) => s.userId), ['account-a']);
      });

      test('rimuove sessioni spurie e mantiene solo account UI', () async {
        manager.injectTestSession(sessionB);
        expect(manager.sessions.length, 2);

        await manager.sessionAuthority.ensureFocusReady('account-a');

        expect(manager.sessions.map((s) => s.userId), ['account-a']);
        expect(manager.isSessionReadyForAccount('account-a'), isTrue);
      });

      test('auth.uid disallineato non è session ready', () async {
        await installTestAuthSession(sessionA.client, userId: 'account-b');

        expect(manager.isSessionReadyForAccount('account-a'), isFalse);

        manager.restoreSessionForTest = (account) async {
          if (account.userId == 'account-a') {
            restoreCallsForA += 1;
            // consolidate dispose la sessione stale: restore deve restituire RAM nuova.
            final refreshed = await AccountSession.createForTest(
              profile: sessionA.profile,
              client: sessionA.client,
              inboxService: sessionA.inboxService,
            );
            await installTestAuthSession(refreshed.client, userId: 'account-a');
            refreshed.wireStorage(storage);
            sessionA = refreshed;
            return refreshed;
          }
          return sessionB;
        };

        await manager.sessionAuthority.ensureFocusReady('account-a');

        expect(restoreCallsForA, greaterThanOrEqualTo(1));
        expect(manager.isSessionReadyForAccount('account-a'), isTrue);
        expect(sessionA.client.auth.currentUser?.id, 'account-a');
      });
    });

    group('Navigation open chat', () {
      late NavigationCoordinator navigation;

      setUp(() {
        navigation = NavigationCoordinator(manager);
      });

      test('openPeerOnFocusedAccount committa subito e consolida in async', () async {
        manager.injectTestSession(sessionB);

        await navigation.openPeerOnFocusedAccount(
          const ChatPeer(
            profile: ProfileSummary(
              id: 'account-b',
              username: 'agent_b',
              displayName: 'Agent B',
            ),
          ),
        );

        expect(navigation.committedScope?.focusUserId, 'account-a');
        expect(navigation.committedScope?.peerProfileId, 'account-b');
        expect(manager.viewState.activePeer?.profileId, 'account-b');

        await pumpEventQueue(times: 20);

        expect(manager.sessions.map((s) => s.userId), ['account-a']);
      });

      test('openConversationOnAccount consolida sessione assente in RAM', () async {
        manager.clearSessionsInRamForTest();

        final ok = await navigation.openConversationOnAccount(
          accountUserId: 'account-a',
          peerProfileId: 'account-b',
          allowProfileFallback: false,
        );

        expect(ok, isTrue);
        expect(manager.isSessionReadyForAccount('account-a'), isTrue);
        expect(navigation.committedScope?.peerProfileId, 'account-b');
      });
    });

    group('AccountNavigationEffects', () {
      test('openConversation via effects con consolidate async', () async {
        late final NavigationMachine machine;
        final effects = AccountNavigationEffects(
          manager,
          focusCommand: _NoOpFocus(manager),
          onInvalidateCommittedScope: () => machine.invalidateCommittedScope(),
          onCommitScope: (scope) => machine.commitScope(scope),
        );
        machine = NavigationMachine(effects);
        manager.clearSessionsInRamForTest();

        final ok = await effects.openConversation(
          accountUserId: 'account-a',
          peerProfileId: 'account-b',
          source: OpenConversationSource.inbox,
        );

        expect(ok, isTrue);
        await pumpEventQueue(times: 20);
        expect(manager.isSessionReadyForAccount('account-a'), isTrue);
        expect(machine.committedScope?.focusUserId, 'account-a');
        expect(machine.committedScope?.peerProfileId, 'account-b');
      });
    });
  });
}

class _NoOpFocus implements AccountFocusCommand {
  _NoOpFocus(this._manager);

  final AccountManager _manager;

  @override
  Future<void> focusAccount(
    String accountUserId, {
    bool deferProfileSync = false,
  }) async {
    if (_manager.focusUserId == accountUserId) return;
  }
}
