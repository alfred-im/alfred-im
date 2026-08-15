// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/message_media_service.dart';

import '../support/composition_harness.dart';
import '../support/session_scope_keys_test_helpers.dart';
import 'package:alfred_client/utils/conversation_session_access.dart';

import '../support/fake_messaging_services.dart';

const _userA = 'account-a';
const _userB = 'account-b';
const _peerId = 'peer-b';

bool _focusedSessionValid(
  AuthController auth,
  String expectedUserId,
  String peerProfileId,
) {
  final live = auth.focusedSession;
  if (live == null || live.userId != expectedUserId) return false;
  return isMessagingSessionReady(
    client: live.client,
    focusUserId: expectedUserId,
    peerProfileId: peerProfileId,
  );
}

/// COMP-001, COMP-002 — PROM-MULTI-ACCOUNT-022
///
/// Composition tier: dopo setFocus round-trip, controller e chiavi scope
/// devono restare allineati alla sessione viva (non istanza dispose).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('COMP messaging session scope', () {
    test('COMP-001 legacy key: uguale dopo recreate sessione (anti-pattern)', () async {
      final setup = await createCompositionAuth(
        accounts: [
          (userId: _userA, username: 'alice'),
          (userId: _userB, username: 'bob'),
        ],
        focusUserId: _userA,
      );

      final sessionBefore = setup.auth.focusedSession!;
      final legacyKeyBefore = legacyMessagesScopeKey(sessionBefore, _peerId);

      await roundTripFocus(
        setup.auth,
        focusUserId: _userA,
        otherUserId: _userB,
      );

      final sessionAfter = setup.auth.focusedSession!;
      expect(sessionAfter, isNot(same(sessionBefore)));
      expect(
        legacyMessagesScopeKey(sessionAfter, _peerId),
        equals(legacyKeyBefore),
      );
    });

    test('COMP-002 production key: cambia dopo recreate sessione', () async {
      final setup = await createCompositionAuth(
        accounts: [
          (userId: _userA, username: 'alice'),
          (userId: _userB, username: 'bob'),
        ],
        focusUserId: _userA,
      );

      final sessionBefore = setup.auth.focusedSession!;
      final productionKeyBefore =
          productionMessagesScopeKey(sessionBefore, _peerId);

      await roundTripFocus(
        setup.auth,
        focusUserId: _userA,
        otherUserId: _userB,
      );

      final sessionAfter = setup.auth.focusedSession!;
      expect(
        productionMessagesScopeKey(sessionAfter, _peerId),
        isNot(equals(productionKeyBefore)),
      );
      expect(
        messagesSessionKey(sessionAfter, _peerId),
        productionMessagesScopeKey(sessionAfter, _peerId),
      );
    });

    test('COMP-001 controller stale invia sul MessageService dispose', () async {
      final setup = await createCompositionAuth(
        accounts: [
          (userId: _userA, username: 'alice'),
          (userId: _userB, username: 'bob'),
        ],
        focusUserId: _userA,
      );

      final sessionBefore = setup.auth.focusedSession!;
      final staleService = setup.servicesBySession[sessionBefore]!;

      final scope = testConversationScope(
        userId: _userA,
        peerProfileId: _peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: _userA,
        peerProfileId: _peerId,
        peerMessages: staleService.peerMessages,
        messageMediaService: MessageMediaService(createTestSupabaseClient()),
        inboxService: FakeInboxService(),
        hasValidSession: () => _focusedSessionValid(setup.auth, _userA, _peerId),
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      await roundTripFocus(
        setup.auth,
        focusUserId: _userA,
        otherUserId: _userB,
      );

      await controller.send('composition-ping');

      expect(staleService.sentBodies, contains('composition-ping'));
      final liveSession = setup.auth.focusedSession!;
      final liveService = setup.servicesBySession[liveSession]!;
      if (!identical(liveService, staleService)) {
        expect(liveService.sentBodies, isEmpty);
      }

      controller.dispose();
    });

    test('COMP-002 controller rebound invia sulla sessione viva', () async {
      final setup = await createCompositionAuth(
        accounts: [
          (userId: _userA, username: 'alice'),
          (userId: _userB, username: 'bob'),
        ],
        focusUserId: _userA,
      );

      final sessionBefore = setup.auth.focusedSession!;

      await roundTripFocus(
        setup.auth,
        focusUserId: _userA,
        otherUserId: _userB,
      );

      final liveSession = setup.auth.focusedSession!;
      expect(liveSession, isNot(same(sessionBefore)));

      final scope = testConversationScope(
        userId: _userA,
        peerProfileId: _peerId,
        sessionEpoch: 1,
      );
      final controller = MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: _userA,
        peerProfileId: _peerId,
        peerMessages: liveSession.peerMessages,
        messageMediaService: liveSession.messageMediaService,
        inboxService: liveSession.inboxService,
        hasValidSession: () => _focusedSessionValid(setup.auth, _userA, _peerId),
        isScopeCommitted: () => true,
      );
      await waitForMessagesController(controller);

      await controller.send('composition-ping');

      expect(controller.error, isNull);
      final liveService = setup.servicesBySession[liveSession]!;
      expect(liveService.sentBodies, contains('composition-ping'));

      final staleService = setup.servicesBySession[sessionBefore]!;
      if (!identical(staleService, liveService)) {
        expect(staleService.sentBodies, isEmpty);
      }

      controller.dispose();
    });
  });
}
