// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/services/group_owner_archive_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

void main() {
  const userId = 'group-1';

  tearDown(() {
    GroupOwnerArchiveCache.evict(userId);
  });

  group('GroupOwnerArchiveCache', () {
    test('forUserId returns shared instance per user', () {
      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);

      final cache = GroupOwnerArchiveCache.forMessageService(
        userId: userId,
        messageService: messageService,
      );
      final other = GroupOwnerArchiveCache.forMessageService(
        userId: userId,
        messageService: messageService,
      );

      expect(identical(cache, other), isTrue);
    });

    test('fetch serves cached messages until forceRefresh', () async {
      final client = createTestSupabaseClient();
      final messageService = FakeMessageService(client);
      messageService.ownerMessagesByUserId[userId] = [
        ChatMessage(
          id: 'm1',
          body: 'ciao',
          timeLabel: '',
          isMine: false,
          createdAt: DateTime.utc(2026, 7, 1),
        ),
      ];

      final cache = GroupOwnerArchiveCache.forMessageService(
        userId: userId,
        messageService: messageService,
      );

      final first = await cache.fetch();
      messageService.ownerMessagesByUserId[userId] = const [];
      final cached = await cache.fetch();

      expect(first, hasLength(1));
      expect(cached, hasLength(1));
      expect(cached.single.body, 'ciao');

      messageService.ownerMessagesByUserId[userId] = [
        ChatMessage(
          id: 'm2',
          body: 'nuovo',
          timeLabel: '',
          isMine: false,
          createdAt: DateTime.utc(2026, 7, 2),
        ),
      ];
      final refreshed = await cache.fetch(forceRefresh: true);

      expect(refreshed.single.body, 'nuovo');
    });
  });
}
