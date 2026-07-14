// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/providers/group_messages_controller.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/media_test_fixtures.dart';

const _groupUser = 'group-user-uuid';

Future<void> _waitForGroupController(GroupMessagesController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GroupMessagesController media broadcast', () {
    late FakeMessageService messageService;
    late FakeMessageMediaService mediaService;
    late GroupMessagesController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      messageService = FakeMessageService(client);
      mediaService = FakeMessageMediaService();
      controller = GroupMessagesController(
        userId: _groupUser,
        messageService: messageService,
        messageMediaService: mediaService,
        profileService: FakeProfileService(client),
      );
      await _waitForGroupController(controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('sendImage broadcasts normalized JPEG to allowlist', () async {
      await controller.sendImage(bytes: kJpegBytes, caption: 'Gruppo');

      expect(mediaService.imageUploads, hasLength(1));
      expect(messageService.imageBroadcasts, hasLength(1));
      expect(messageService.imageBroadcasts.single['body'], 'Gruppo');
      expect(messageService.imageBroadcasts.single['mediaMime'], 'image/jpeg');
      expect(controller.error, isNull);
    });

    test('sendVideo broadcasts mp4 to allowlist', () async {
      await controller.sendVideo(
        bytes: kMp4Bytes,
        extension: 'mp4',
        mime: 'video/mp4',
        durationSeconds: 4,
        caption: 'Video gruppo',
      );

      expect(mediaService.videoUploads, hasLength(1));
      expect(messageService.videoBroadcasts, hasLength(1));
      expect(messageService.videoBroadcasts.single['durationSeconds'], 4);
      expect(messageService.videoBroadcasts.single['body'], 'Video gruppo');
      expect(controller.error, isNull);
    });
  });
}
