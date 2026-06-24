import 'package:flutter/material.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.preview,
    required this.timeLabel,
    required this.unreadCount,
    required this.avatarColor,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;
}
