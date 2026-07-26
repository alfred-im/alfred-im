// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/mock_path_provider.dart';

/// Scenario reale (Aga 1 → test 2, invio GIF):
/// UI su account A, chat con B, ma JWT GoTrue su B → RPC `cannot message yourself`.
///
/// PROM-CONVERSATION-SCOPE-009 (bozza): identità certa per tutta la chat, non solo
/// all'apertura. Questi test devono passare **prima** del fix in produzione.
const _accountAga1 = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _peerTest2 = '0a81f785-173c-4f1c-b5df-3937086a2482';

/// GIF89a minimo per `sendGif`.
final kMinimalGifBytes = Uint8List.fromList([
  0x47,
  0x49,
  0x46,
  0x38,
  0x39,
  0x61,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PROM-CONVERSATION-SCOPE-009 messaging identity on send', () {
    late FakeMessageService messageService;
    late FakeMessageMediaService mediaService;

    setUp(() async {
      setUpMockPathProvider();
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      await installTestAuthSession(client, userId: _peerTest2);
      messageService = FakeMessageService(client);
      mediaService = FakeMessageMediaService();
    });

    /// Simula il check debole attuale: JWT presente, identità non verificata.
    bool weakJwtOnlySessionCheck() {
      final token = messageService.client.auth.currentSession?.accessToken;
      return token != null && token.isNotEmpty;
    }

    MessagesController createMisalignedController() {
      final scope = testConversationScope(
        userId: _accountAga1,
        peerProfileId: _peerTest2,
        sessionEpoch: 1,
      );
      return MessagesController(
        scope: scope,
        messageStore: testMessageStoreFor(scope),
        userId: _accountAga1,
        peerProfileId: _peerTest2,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: FakeInboxService(),
        outboundQueue: OutboundMessageQueue(),
        hasValidSession: weakJwtOnlySessionCheck,
        isScopeCommitted: () => true,
      );
    }

    test('send testo: JWT del peer blocca RPC senza PostgrestException in UI', () async {
      final controller = createMisalignedController();
      await waitForMessagesController(controller);

      await controller.send('ping da Aga1 verso test2');

      expect(
        messageService.sentBodies,
        isEmpty,
        reason: 'RPC non deve partire con auth.uid = destinatario',
      );
      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(controller.error, isNot(contains('PostgrestException')));
      expect(controller.error, isNot(contains('cannot message yourself')));

      controller.dispose();
    });

    test('sendGif: JWT del peer blocca RPC (report Aga1 → test2)', () async {
      final controller = createMisalignedController();
      await waitForMessagesController(controller);

      await controller.sendGif(kMinimalGifBytes);

      expect(
        messageService.gifProfileSends,
        isEmpty,
        reason: 'send_message_to_profile non deve essere chiamato',
      );
      expect(
        mediaService.gifUploads,
        isEmpty,
        reason: 'upload media non deve partire senza identità certa',
      );
      expect(controller.error, MessagesController.sessionExpiredMessage);
      expect(controller.error, isNot(contains('PostgrestException')));

      controller.dispose();
    });

    test('regressione: senza gate identità il server rifiuterebbe il testo', () async {
      expect(
        () => messageService.enforceSendToProfileBoundary(_peerTest2),
        throwsA(
          isA<PostgrestException>().having(
            (e) => e.message,
            'message',
            'cannot message yourself',
          ),
        ),
      );
    });
  });
}
