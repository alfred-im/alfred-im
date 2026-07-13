// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/utils/merge_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge preserves image media on tick-only realtime update', () {
    const existing = ChatMessage(
      id: 'client-id',
      body: 'Didascalia',
      timeLabel: '12:00',
      isMine: true,
      contentType: MessageContentType.image,
      mediaUrl: 'https://example.com/photo.jpg',
      clientMessageId: 'client-id',
    );

    final tickUpdate = ChatMessage.fromJson(
      json: {
        'id': 'server-id',
        'body': '',
        'created_at': DateTime.utc(2026, 7, 13, 12).toIso8601String(),
        'author_id': 'me',
        'client_message_id': 'client-id',
        'delivered_at': DateTime.utc(2026, 7, 13, 12, 1).toIso8601String(),
      },
      currentUserId: 'me',
    );

    final merged = mergeChatMessage(existing: existing, incoming: tickUpdate);

    expect(merged.id, 'server-id');
    expect(merged.contentType, MessageContentType.image);
    expect(merged.mediaUrl, 'https://example.com/photo.jpg');
    expect(merged.body, 'Didascalia');
    expect(merged.status, MessageStatus.delivered);
  });

  test('merge keeps media_url when update has image type but no url', () {
    const existing = ChatMessage(
      id: 'client-id',
      body: '',
      timeLabel: '12:00',
      isMine: true,
      contentType: MessageContentType.image,
      mediaUrl: 'https://example.com/photo.jpg',
      clientMessageId: 'client-id',
    );

    final partialUpdate = ChatMessage.fromJson(
      json: {
        'id': 'server-id',
        'body': '',
        'content_type': 'image',
        'created_at': DateTime.utc(2026, 7, 13, 12).toIso8601String(),
        'author_id': 'me',
        'client_message_id': 'client-id',
        'delivered_at': DateTime.utc(2026, 7, 13, 12, 1).toIso8601String(),
      },
      currentUserId: 'me',
    );

    final merged = mergeChatMessage(existing: existing, incoming: partialUpdate);

    expect(merged.contentType, MessageContentType.image);
    expect(merged.mediaUrl, 'https://example.com/photo.jpg');
  });
}
