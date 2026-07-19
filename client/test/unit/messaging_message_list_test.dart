// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/messaging/messaging_message_list.dart';
import 'package:alfred_client/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prependOlderMessages', () {
    test('prepends older page without duplicating overlaps', () {
      final existing = [
        ChatMessage(
          id: '2',
          body: 'recent',
          timeLabel: '12:01',
          isMine: true,
          createdAt: DateTime.utc(2026, 7, 19, 12, 1),
        ),
      ];
      final older = [
        ChatMessage(
          id: '1',
          body: 'older',
          timeLabel: '12:00',
          isMine: false,
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
        ChatMessage(
          id: '2',
          body: 'recent duplicate',
          timeLabel: '12:01',
          isMine: true,
          createdAt: DateTime.utc(2026, 7, 19, 12, 1),
        ),
      ];

      final merged = prependOlderMessages(existing: existing, older: older);

      expect(merged, hasLength(2));
      expect(merged.first.id, '1');
      expect(merged.last.body, 'recent');
    });
  });
}
