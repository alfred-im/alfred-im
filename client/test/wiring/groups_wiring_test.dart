// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/group_home_controller.dart';
import 'package:alfred_client/providers/group_messages_controller.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';

import '../support/fake_messaging_services.dart';

Future<void> _waitForGroupController(GroupMessagesController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

/// Wiring: GroupHomeController / GroupMessagesController → coordinator live.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('groups wiring', () {
    const groupId = 'group-1';
    const marioId = 'mario';

    test('GroupHomeController load attraversa coordinator live', () async {
      const groupProfile = ProfileSummary(
        id: groupId,
        displayName: 'Famiglia',
        username: 'famiglia',
        profileKind: ProfileKind.group,
      );
      const mario = ProfileSummary(
        id: marioId,
        displayName: 'Mario',
        username: 'mario',
      );

      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);
      messageService.archiveMessagesByUserId[groupId] = [
        ChatMessage(
          id: 'm1',
          body: 'ciao',
          timeLabel: '',
          isMine: false,
          originalAuthorId: marioId,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ];

      final profileService = FakeProfileService(client)
        ..profilesById[marioId] = mario;

      final session = await AccountSession.createForTest(
        profile: groupProfile,
        client: client,
        peerMessages: messageService.peerMessages,
        groupArchive: messageService.groupArchive,
        messageMediaService: MessageMediaService(client),
      );
      session.fullProfile = UserProfile(
        summary: groupProfile,
        createdAt: DateTime.utc(2026, 3, 12),
        updatedAt: DateTime.utc(2026, 3, 12),
      );
      addTearDown(() => session.disposeResources(clearAuthStorage: false));

      final controller = GroupHomeController(
        session: session,
        profile: groupProfile,
        profileService: profileService,
      );
      addTearDown(controller.dispose);

      for (var i = 0; i < 200 && controller.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(controller.totalMessageCount, 1);
      expect(controller.activeAuthors.single.profile.id, marioId);
    });

    test('home and messages coordinators share archive user cache', () async {
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);
      messageService.archiveMessagesByUserId[groupId] = [
        ChatMessage(
          id: 'm1',
          body: 'ciao',
          timeLabel: '',
          isMine: false,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ];

      final home = GroupHomeController(
        session: await AccountSession.createForTest(
          profile: const ProfileSummary(
            id: groupId,
            displayName: 'Famiglia',
            username: 'famiglia',
            profileKind: ProfileKind.group,
          ),
          client: client,
          groupArchive: messageService.groupArchive,
          messageMediaService: MessageMediaService(client),
        ),
        profile: const ProfileSummary(
          id: groupId,
          displayName: 'Famiglia',
          username: 'famiglia',
          profileKind: ProfileKind.group,
        ),
        profileService: FakeProfileService(client),
      );
      addTearDown(home.dispose);

      for (var i = 0; i < 200 && home.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final messages = GroupMessagesController(
        userId: groupId,
        groupArchive: messageService.groupArchive,
        messageMediaService: MessageMediaService(client),
        profileService: FakeProfileService(client),
        archiveCache: home.archiveCache,
      );
      await _waitForGroupController(messages);
      addTearDown(messages.dispose);

      expect(identical(home.archiveCache, messages.archiveCache), isTrue);
      expect(messages.messages, hasLength(1));
    });

    test('GroupMessagesController send attraversa coordinator live', () async {
      SharedPreferences.setMockInitialValues({});
      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);

      final controller = GroupMessagesController(
        userId: groupId,
        groupArchive: messageService.groupArchive,
        messageMediaService: MessageMediaService(client),
        profileService: FakeProfileService(client),
      );
      await _waitForGroupController(controller);
      addTearDown(controller.dispose);

      await controller.send('ciao gruppo');

      expect(messageService.broadcastBodies, contains('ciao gruppo'));
      expect(controller.isSending, isFalse);
      expect(controller.error, isNull);
    });
  });
}
