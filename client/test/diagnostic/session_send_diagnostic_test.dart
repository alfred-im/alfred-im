// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

@Tags(['diagnostic'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/utils/diagnostic_log.dart';

import '../support/diagnostic_harness.dart';
import '../support/session_scope_keys_test_helpers.dart';
import '../support/fake_messaging_services.dart';
import '../support/wiring_test_fixtures.dart';

/// Diagnosi flussi messaging/session — usa [DiagnosticHarness] (hub strutturato).
///
/// Lancio:
/// ```bash
/// cd client && flutter test --tags diagnostic test/diagnostic/
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiagnosticHarness harness;

  setUp(() {
    harness = DiagnosticHarness();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (harness.lines.isNotEmpty) {
      // ignore: avoid_print
      print(
        '=== ALFRED DIAGNOSTIC EVENTS (tearDown) ===\n'
        '${harness.lines.join('\n')}',
      );
    }
    harness.dispose();
  });

  group('session send diagnostic', () {
    test('send con JWT assente logga messaging.session.check FAIL jwt_missing', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();

      final scope = testConversationScope(
        userId: userId,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: userId,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => false,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'session.check',
          failureOnly: true,
        ),
        isTrue,
      );

      harness.clear();
      await controller.send('ciao diagnosi');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'send.guard',
          failureOnly: true,
        ),
        isTrue,
        reason: 'send con sessionBlocked deve loggare send.guard session_blocked',
      );

      controller.dispose();
    });

    test('JWT invalidato dopo load ok → send logga jwt_missing', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();
      var sessionValid = true;

      final scope = testConversationScope(
        userId: userId,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: userId,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);
      expect(controller.error, isNull);

      sessionValid = false;
      harness.clear();
      await controller.send('dopo load ok');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'session.check',
          failureOnly: true,
        ),
        isTrue,
      );

      controller.dispose();
    });

    test('focus switch A→B→A ricrea scope key → send ok con sessione viva', () async {
      const userA = 'account-a';
      const userB = 'account-b';
      const peerId = 'peer-b';

      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: userA, username: 'alice'),
          openAccount(userId: userB, username: 'bob'),
        ],
        focusUserId: userA,
      );

      final manager = AccountManager(storage: storage)
        ..restoreSessionForTest = (account) async {
          final client = createTestSupabaseClient();
          return AccountSession.createForTest(
            profile: account.profile,
            client: client,
          );
        };

      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      final sessionAtOpen = auth.focusedSession!;
      var sessionValid = true;
      final client = createTestSupabaseClient();
      final scope = testConversationScope(
        userId: userA,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: userA,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);
      expect(controller.error, isNull);

      await auth.setFocus(userB);
      await auth.setFocus(userA);
      final liveSession = auth.focusedSession!;
      expect(liveSession, isNot(same(sessionAtOpen)));

      final reboundScope = testConversationScope(
        userId: userA,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final reboundController = MessagesController(
        scope: reboundScope,
        messageStore: testMessageStoreFor(reboundScope),
        userId: userA,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: FakeInboxService(),
        hasValidSession: () => true,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(reboundController);
      expect(messagesSessionKey(liveSession, peerId), isNotNull);

      harness.clear();
      await reboundController.send('dopo rebind sessione');

      expect(reboundController.error, isNull);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'session.check',
          failureOnly: true,
        ),
        isFalse,
      );

      controller.dispose();
      reboundController.dispose();
    });

    test('controller stale senza rebind → send fallisce (regressione bug PWA)', () async {
      const userA = 'account-a';
      const userB = 'account-b';
      const peerId = 'peer-b';

      final storage = AccountStorageService();
      await seedAccountsInStorage(
        storage: storage,
        accounts: [
          openAccount(userId: userA, username: 'alice'),
          openAccount(userId: userB, username: 'bob'),
        ],
        focusUserId: userA,
      );

      final manager = AccountManager(storage: storage)
        ..restoreSessionForTest = (account) async {
          return AccountSession.createForTest(
            profile: account.profile,
            client: createTestSupabaseClient(),
          );
        };

      final auth = await createWiredAuthController(manager: manager);
      await auth.initialize();

      var sessionValid = true;
      final client = createTestSupabaseClient();
      final scope = testConversationScope(
        userId: userA,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: userA,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      await auth.setFocus(userB);
      await auth.setFocus(userA);

      sessionValid = false;

      harness.clear();
      await controller.send('senza rebind');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'session.check',
          failureOnly: true,
        ),
        isTrue,
      );

      controller.dispose();
    });

    test('gate wiring non copre JWT: hasValidSession sempre true', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();

      final scope = testConversationScope(
        userId: userId,
        peerProfileId: peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: userId,
        peerProfileId: peerId,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => true,
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      harness.clear();
      await controller.send('wiring ignora JWT');

      expect(controller.error, isNull);
      expect(
        harness.any(
          flow: DiagnosticFlows.messaging,
          phaseContains: 'send.done',
        ),
        isTrue,
      );

      controller.dispose();
    });
  });
}
