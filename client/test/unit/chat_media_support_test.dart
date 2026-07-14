// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/config/chat_media_config.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/services/outbound_media_cache.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';
import 'package:alfred_client/utils/media_probe_timeout.dart';
import 'package:alfred_client/utils/prepare_image_for_upload.dart';

import '../support/fake_messaging_services.dart';
import '../support/media_test_fixtures.dart';
import '../support/mock_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ChatMediaConfig outbound persist policy', () {
    test('skips web SharedPreferences persist for large blobs', () {
      expect(ChatMediaConfig.shouldPersistOutboundMediaOnWeb(1024), isTrue);
      expect(
        ChatMediaConfig.shouldPersistOutboundMediaOnWeb(
          ChatMediaConfig.webOutboundPersistMaxBytes + 1,
        ),
        isFalse,
      );
    });
  });

  group('media_probe_timeout', () {
    test('returns onTimeout when probe exceeds budget', () async {
      final result = await withMediaProbeTimeout<int>(
        Future<int>.delayed(const Duration(seconds: 10), () => 42),
        onTimeout: () => -1,
      );
      expect(result, -1);
    });

    test('returns value when probe finishes in time', () async {
      final result = await withMediaProbeTimeout<int>(
        Future<int>.value(7),
        onTimeout: () => -1,
      );
      expect(result, 7);
    });
  });

  group('prepareImageForUpload', () {
    test('passes JPEG through on IO', () async {
      final normalized = await prepareImageForUpload(kJpegBytes);
      expect(normalized.mime, 'image/jpeg');
      expect(normalized.extension, 'jpg');
      expect(normalized.bytes, kJpegBytes);
    });
  });

  group('MessageMediaService limits', () {
    test('uploadImage rejects oversize payload before storage', () async {
      final service = MessageMediaService(createTestSupabaseClient());
      final huge = Uint8List(ChatMediaConfig.imageMaxBytes + 1);

      expect(
        () => service.uploadImage(
          bytes: huge,
          userId: 'user',
          extension: 'jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('uploadVideo rejects oversize payload before storage', () async {
      final service = MessageMediaService(createTestSupabaseClient());
      final huge = Uint8List(ChatMediaConfig.videoMaxBytes + 1);

      expect(
        () => service.uploadVideo(
          bytes: huge,
          userId: 'user',
          extension: 'mp4',
          contentType: 'video/mp4',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('OutboundMessageQueue media bytes', () {
    test('persistMediaBytes stores bytes in OutboundMediaCache', () async {
      setUpMockPathProvider();
      SharedPreferences.setMockInitialValues({});
      final queue = OutboundMessageQueue();
      const clientId = 'media-client';

      await queue.persistMediaBytes(
        clientId: clientId,
        bytes: kMp4Bytes,
        extension: 'mp4',
      );

      expect(OutboundMediaCache.instance.peek(clientId), kMp4Bytes);
      await queue.deleteMediaFile('memory://$clientId', clientId: clientId);
      expect(OutboundMediaCache.instance.peek(clientId), isNull);
    });
  });
}
