// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';
import 'package:alfred_client/utils/conversation_session_access.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/mock_path_provider.dart';

const _archiveUserA = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _peerB = '0a81f785-173c-4f1c-b5df-3937086a2482';

final _minimalGifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationSessionAccess', () {
    group('invarianti', () {
      test('account allineato con JWT valido', () async {
        final client = createTestSupabaseClient();
        await installTestAuthSession(client, userId: _archiveUserA);

        expect(
          isAccountSessionReady(client: client, focusUserId: _archiveUserA),
          isTrue,
        );
        expect(
          isMessagingSessionReady(
            client: client,
            focusUserId: _archiveUserA,
            peerProfileId: _peerB,
          ),
          isTrue,
        );
      });

      test('messaggistica rifiuta auth.uid = peer (Aga1 UI, JWT test2)', () async {
        final client = createTestSupabaseClient();
        await installTestAuthSession(client, userId: _peerB);

        expect(
          isMessagingSessionReady(
            client: client,
            focusUserId: _archiveUserA,
            peerProfileId: _peerB,
          ),
          isFalse,
        );
      });

      test('friendlyMessagingError nasconde PostgrestException', () {
        expect(
          friendlyMessagingError(
            const PostgrestException(
              message: 'cannot message yourself',
              code: 'P0001',
            ),
          ),
          conversationSessionExpiredMessage,
        );
      });
    });

    group('send contract', () {
      late FakeMessageService messageService;
      late FakeMessageMediaService mediaService;

      setUp(() async {
        setUpMockPathProvider();
        SharedPreferences.setMockInitialValues({});
        final client = createTestSupabaseClient();
        await installTestAuthSession(client, userId: _peerB);
        messageService = FakeMessageService(client);
        mediaService = FakeMessageMediaService();
      });

      MessagesController misalignedController() {
        final scope = testConversationScope(
          userId: _archiveUserA,
          peerProfileId: _peerB,
          sessionEpoch: 1,
        );
        return MessagesController(
          scope: scope,
          messageStore: testMessageStoreFor(scope),
          userId: _archiveUserA,
          peerProfileId: _peerB,
          peerMessages: messageService.peerMessages,
          messageMediaService: mediaService,
          inboxService: FakeInboxService(),
          outboundQueue: OutboundMessageQueue(),
          hasValidSession: () => isMessagingSessionReady(
            client: messageService.client,
            focusUserId: _archiveUserA,
            peerProfileId: _peerB,
            whenNoGoTrueSession: () => false,
          ),
          isScopeCommitted: () => true,
        );
      }

      test('testo: nessuna RPC, messaggio sessione scaduta', () async {
        final controller = misalignedController();
        await waitForMessagesController(controller);

        await controller.send('ping');

        expect(messageService.sentBodies, isEmpty);
        expect(controller.error, conversationSessionExpiredMessage);
        expect(controller.error, isNot(contains('PostgrestException')));

        controller.dispose();
      });

      test('GIF: nessun upload né RPC', () async {
        final controller = misalignedController();
        await waitForMessagesController(controller);

        await controller.sendGif(_minimalGifBytes);

        expect(messageService.gifProfileSends, isEmpty);
        expect(mediaService.gifUploads, isEmpty);
        expect(controller.error, conversationSessionExpiredMessage);

        controller.dispose();
      });
    });
  });
}
