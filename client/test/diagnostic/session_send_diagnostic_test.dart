// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

@Tags(['diagnostic'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/utils/session_scope_keys.dart';

import '../support/fake_messaging_services.dart';
import '../support/wiring_test_fixtures.dart';

/// Diagnosi «Sessione scaduta» all'invio — raccolta log `[alfred]` come
/// `e2e/helpers/diagnostic-logs.ts` (`dumpDiagnosticLogsOnFailure` su fail).
///
/// Lancio:
/// ```bash
/// cd client && flutter test --dart-define=ALFRED_DIAGNOSTIC_LOG=true \
///   --tags diagnostic \
///   test/diagnostic/session_send_diagnostic_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final diagnosticLogs = <String>[];
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    diagnosticLogs.clear();
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('[alfred]')) {
        diagnosticLogs.add(message);
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    if (diagnosticLogs.isNotEmpty) {
      originalDebugPrint(
        '=== ALFRED DIAGNOSTIC LOGS (tearDown) ===\n'
        '${diagnosticLogs.join('\n')}',
      );
    }
  });

  group('session send diagnostic', () {
    test('send con JWT assente logga messaging.session.check FAIL jwt_missing', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();

      final controller = MessagesController(
        userId: userId,
        peerProfileId: peerId,
        messageService: FakeMessageService(client),
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => false,
      );
      await waitForMessagesController(controller);

      expect(
        controller.error,
        MessagesController.sessionExpiredMessage,
        reason: 'load deve bloccare senza JWT',
      );
      expect(
        diagnosticLogs.any(
          (line) =>
              line.contains('[messaging] session.check') &&
              line.contains('FAIL jwt_missing'),
        ),
        isTrue,
      );

      diagnosticLogs.clear();
      await controller.send('ciao diagnosi');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        diagnosticLogs,
        isEmpty,
        reason:
            'send con sessionBlocked esce in silenzio (coordinator) — nessun secondo log',
      );

      controller.dispose();
    });

    test('JWT invalidato dopo load ok → send logga jwt_missing', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();
      var sessionValid = true;

      final controller = MessagesController(
        userId: userId,
        peerProfileId: peerId,
        messageService: FakeMessageService(client),
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
      );
      await waitForMessagesController(controller);
      expect(controller.error, isNull);

      sessionValid = false;
      diagnosticLogs.clear();
      await controller.send('dopo load ok');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        diagnosticLogs.any(
          (line) =>
              line.contains('[messaging] session.check') &&
              line.contains('FAIL jwt_missing'),
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
      final controller = MessagesController(
        userId: userA,
        peerProfileId: peerId,
        messageService: FakeMessageService(client),
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
      );
      await waitForMessagesController(controller);
      expect(controller.error, isNull);

      await auth.setFocus(userB);
      await auth.setFocus(userA);
      final liveSession = auth.focusedSession!;
      expect(liveSession, isNot(same(sessionAtOpen)));

      final reboundController = MessagesController(
        userId: userA,
        peerProfileId: peerId,
        messageService: FakeMessageService(createTestSupabaseClient()),
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: FakeInboxService(),
        hasValidSession: () => true,
      );
      await waitForMessagesController(reboundController);
      expect(messagesSessionKey(liveSession, peerId), isNotNull);

      diagnosticLogs.clear();
      await reboundController.send('dopo rebind sessione');

      expect(reboundController.error, isNull);
      expect(
        diagnosticLogs.any((line) => line.contains('FAIL jwt_missing')),
        isFalse,
        reason: 'con key+sessione viva il send non deve fallire su JWT',
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
      final controller = MessagesController(
        userId: userA,
        peerProfileId: peerId,
        messageService: FakeMessageService(client),
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => sessionValid,
      );
      await waitForMessagesController(controller);

      await auth.setFocus(userB);
      await auth.setFocus(userA);

      sessionValid = false;

      diagnosticLogs.clear();
      await controller.send('senza rebind');

      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(
        diagnosticLogs.any((line) => line.contains('FAIL jwt_missing')),
        isTrue,
      );

      controller.dispose();
    });

    test('gate wiring non copre JWT: hasValidSession sempre true', () async {
      const userId = 'user-a';
      const peerId = 'peer-b';
      final client = createTestSupabaseClient();

      final controller = MessagesController(
        userId: userId,
        peerProfileId: peerId,
        messageService: FakeMessageService(client),
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
        hasValidSession: () => true,
      );
      await waitForMessagesController(controller);

      await controller.send('wiring ignora JWT');

      expect(controller.error, isNull);
      expect(
        diagnosticLogs.any(
          (line) =>
              line.contains('[messaging] session.check') &&
              line.contains('ok=true'),
        ),
        isTrue,
      );

      controller.dispose();
    });
  });
}
