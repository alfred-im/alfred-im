import 'package:flutter/material.dart';

import '../utils/avatar_color.dart';
import '../utils/date_format.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
    required this.avatarColor,
    this.isOnline = false,
    this.lastMessageAt,
    this.protocol = 'internal',
  });

  final String id;
  final String name;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;
  final DateTime? lastMessageAt;
  final String protocol;

  factory Conversation.fromJoinedRow({
    required Map<String, dynamic> conversation,
    required Map<String, dynamic> participant,
    required String displayName,
    String? avatarKey,
  }) {
    final lastAt = conversation['last_message_at'] != null
        ? DateTime.parse(conversation['last_message_at'] as String)
        : null;

    return Conversation(
      id: conversation['id'] as String,
      name: displayName,
      preview: (conversation['last_message_preview'] as String?) ?? '',
      timeLabel: formatConversationTime(lastAt),
      unreadCount: participant['unread_count'] as int? ?? 0,
      avatarColor: avatarColorForId(avatarKey ?? displayName),
      lastMessageAt: lastAt,
      protocol: conversation['protocol'] as String? ?? 'internal',
    );
  }
}
