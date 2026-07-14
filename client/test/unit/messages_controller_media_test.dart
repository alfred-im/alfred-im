// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/outbound_media_cache.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/media_test_fixtures.dart';
import '../support/mock_path_provider.dart';

const _agent1 = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';
const _agent2 = '0a81f785-173c-4f1c-b5df-3937086a2482';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessagesController media send', () {
    late FakeMessageService messageService;
    late FakeMessageMediaService mediaService;
    late OutboundMessageQueue outboundQueue;
    late MessagesController controller;

    setUp(() async {
      setUpMockPathProvider();
      SharedPreferences.setMockInitialValues({});
      OutboundMediaCache.instance.remove('any');
      messageService = FakeMessageService(createTestSupabaseClient());
      mediaService = FakeMessageMediaService();
      outboundQueue = OutboundMessageQueue();
      controller = MessagesController(
        userId: _agent1,
        peerProfileId: _agent2,
        messageService: messageService,
        messageMediaService: mediaService,
        inboxService: FakeInboxService(),
        outboundQueue: outboundQueue,
      );
      await waitForMessagesController(controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('sendImage shows pending bubble before upload completes', () async {
      final uploadGate = Completer<void>();
      mediaService.uploadImageGate = uploadGate.future;

      final sendFuture = controller.sendImage(
        bytes: kJpegBytes,
        caption: 'Al mare',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.messages, hasLength(1));
      final pending = controller.messages.single;
      expect(pending.contentType, MessageContentType.image);
      expect(pending.mediaUrl, startsWith('pending://'));
      expect(pending.status, MessageStatus.pending);
      expect(pending.body, 'Al mare');
      expect(mediaService.imageUploads, isEmpty);

      uploadGate.complete();
      await sendFuture;

      expect(messageService.imageProfileSends, hasLength(1));
      expect(controller.messages.single.mediaUrl, contains('storage.example'));
      expect(controller.messages.single.status, MessageStatus.sent);
    });

    test('sendImage caches raw bytes for pending preview', () async {
      final uploadGate = Completer<void>();
      mediaService.uploadImageGate = uploadGate.future;

      final sendFuture = controller.sendImage(bytes: kJpegBytes);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final pendingId = controller.messages.single.clientMessageId!;
      expect(OutboundMediaCache.instance.peek(pendingId), kJpegBytes);

      uploadGate.complete();
      await sendFuture;

      expect(OutboundMediaCache.instance.peek(pendingId), isNull);
      expect(messageService.imageProfileSends.single['mediaMime'], 'image/jpeg');
    });

    test('sendImage rejects unknown format without bubble', () async {
      await controller.sendImage(bytes: Uint8List.fromList([0, 1, 2]));

      expect(controller.messages, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('sendVideo shows pending bubble before stream bytes arrive', () async {
      final streamController = StreamController<List<int>>();
      final file = PlatformFile(
        name: 'clip.mp4',
        size: kMp4Bytes.length,
        readStream: streamController.stream,
      );
      mediaService.uploadVideoGate = Future<void>.delayed(
        const Duration(milliseconds: 50),
      );

      final sendFuture = controller.sendVideoFromPicker(file: file);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.contentType, MessageContentType.video);
      expect(controller.messages.single.mediaUrl, startsWith('pending://'));
      expect(mediaService.videoUploads, isEmpty);

      streamController.add(kMp4Bytes);
      await streamController.close();
      await sendFuture;

      expect(messageService.videoProfileSends, hasLength(1));
      expect(controller.messages.single.status, MessageStatus.sent);
    });

    test('sendVideoFromPicker marks failed when bytes are unreadable', () async {
      final file = PlatformFile(name: 'empty.mp4', size: 0);

      await controller.sendVideoFromPicker(file: file);

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.status, MessageStatus.failed);
      expect(controller.error, isNotNull);
      expect(messageService.videoProfileSends, isEmpty);
    });

    test('sendVideo reports error when already sending', () async {
      controller.isSending = true;

      await controller.sendVideo(
        bytes: kMp4Bytes,
        extension: 'mp4',
        mime: 'video/mp4',
        durationSeconds: 2,
      );

      expect(controller.messages, isEmpty);
      expect(controller.error, contains('Invio già in corso'));
    });

    test('sendVideo completes upload with caption', () async {
      await controller.sendVideo(
        bytes: kMp4Bytes,
        extension: 'mp4',
        mime: 'video/mp4',
        durationSeconds: 3,
        caption: 'Clip',
      );

      expect(messageService.videoProfileSends, hasLength(1));
      expect(messageService.videoProfileSends.single['body'], 'Clip');
      expect(mediaService.videoUploads.single.contentType, 'video/mp4');
      expect(controller.messages.single.contentType, MessageContentType.video);
    });
  });
}
