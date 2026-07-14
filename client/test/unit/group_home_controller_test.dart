// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/providers/group_home_controller.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/utils/message_preview.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-GROUP-HOME-005, SURF-GROUP-HOME-006
void main() {
  group('inboxPreviewForMessage', () {
    test('maps media types like inbox preview', () {
      expect(
        inboxPreviewForMessage(
          const ChatMessage(
            id: '1',
            body: '',
            timeLabel: '',
            isMine: false,
            contentType: MessageContentType.gif,
            mediaUrl: 'https://example.com/a.gif',
          ),
        ),
        '[GIF]',
      );
      expect(
        inboxPreviewForMessage(
          const ChatMessage(
            id: '2',
            body: 'Al mare',
            timeLabel: '',
            isMine: false,
            contentType: MessageContentType.image,
            mediaUrl: 'https://example.com/a.jpg',
          ),
        ),
        '📷 Al mare',
      );
      expect(
        inboxPreviewForMessage(
          const ChatMessage(
            id: '3',
            body: '',
            timeLabel: '',
            isMine: false,
            contentType: MessageContentType.video,
            mediaUrl: 'https://example.com/a.mp4',
            durationSeconds: 10,
          ),
        ),
        '🎬 Video',
      );
    });
  });

  group('GroupHomeController', () {
    test('aggregates active authors excluding group id', () async {
      const groupProfile = ProfileSummary(
        id: 'group-1',
        displayName: 'Famiglia',
        username: 'famiglia',
        profileKind: ProfileKind.group,
      );
      const mario = ProfileSummary(
        id: 'mario',
        displayName: 'Mario',
        username: 'mario',
      );
      const lucia = ProfileSummary(
        id: 'lucia',
        displayName: 'Lucia',
        username: 'lucia',
      );

      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);
      messageService.ownerMessagesByUserId['group-1'] = [
        ChatMessage(
          id: 'm1',
          body: 'ciao',
          timeLabel: '',
          isMine: false,
          originalAuthorId: 'mario',
          createdAt: DateTime.utc(2026, 7, 1),
        ),
        ChatMessage(
          id: 'm2',
          body: 'ancora',
          timeLabel: '',
          isMine: false,
          originalAuthorId: 'mario',
          createdAt: DateTime.utc(2026, 7, 2),
        ),
        ChatMessage(
          id: 'm3',
          body: 'hey',
          timeLabel: '',
          isMine: false,
          originalAuthorId: 'lucia',
          createdAt: DateTime.utc(2026, 7, 3),
        ),
        ChatMessage(
          id: 'm4',
          body: 'broadcast',
          timeLabel: '',
          isMine: true,
          originalAuthorId: 'group-1',
          createdAt: DateTime.utc(2026, 7, 4),
        ),
      ];

      final profileService = FakeProfileService(client)
        ..profilesById.addAll({
          'mario': mario,
          'lucia': lucia,
        });

      final session = await AccountSession.createForTest(
        profile: groupProfile,
        client: client,
        messageService: messageService,
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
        messageService: messageService,
        profileService: profileService,
      );

      for (var i = 0; i < 200 && controller.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(controller.totalMessageCount, 4);
      expect(controller.activeAuthors.length, 2);
      expect(controller.activeAuthors.first.profile.id, 'mario');
      expect(controller.activeAuthors.first.messageCount, 2);
      expect(controller.activeAuthors.last.profile.id, 'lucia');
      expect(controller.conversationTile?.preview, 'broadcast');
      expect(
        GroupHomeController.formatBirthDate(DateTime.utc(2026, 3, 12)),
        '12 mar 2026',
      );
    });
  });
}
