import 'package:flutter/material.dart';

import '../utils/avatar_color.dart';
import '../utils/date_format.dart';

/// Controparte di una chat — identificata solo da account (profile_id).
class ChatPeer {
  const ChatPeer({
    required this.profileId,
    required this.displayName,
    this.address,
    this.preview = '',
    this.timeLabel = '',
    this.unreadCount = 0,
    this.lastMessageAt,
    this.protocol = 'internal',
    this.peerExternalAddress,
    this.avatarColor,
  });

  final String profileId;
  final String displayName;
  final String? address;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String protocol;
  final String? peerExternalAddress;
  final Color? avatarColor;

  Color get resolvedAvatarColor =>
      avatarColor ?? avatarColorForId(displayName);

  bool get hasInboxHistory => lastMessageAt != null;

  factory ChatPeer.fromInboxRow(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String;
    final lastAt = json['last_message_at'] != null
        ? DateTime.parse(json['last_message_at'] as String)
        : null;

    return ChatPeer(
      profileId: json['peer_profile_id'] as String,
      displayName: displayName,
      preview: (json['last_message_preview'] as String?) ?? '',
      timeLabel: formatConversationTime(lastAt),
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageAt: lastAt,
      protocol: json['protocol'] as String? ?? 'internal',
      peerExternalAddress: json['peer_external_address'] as String?,
    );
  }

  factory ChatPeer.internal({
    required String profileId,
    required String displayName,
    required String address,
  }) {
    return ChatPeer(
      profileId: profileId,
      displayName: displayName,
      address: address,
    );
  }

  ChatPeer mergeFromInbox(ChatPeer inboxRow) {
    return ChatPeer(
      profileId: profileId,
      displayName: displayName,
      address: address,
      preview: inboxRow.preview,
      timeLabel: inboxRow.timeLabel,
      unreadCount: inboxRow.unreadCount,
      lastMessageAt: inboxRow.lastMessageAt,
      protocol: inboxRow.protocol,
      peerExternalAddress: inboxRow.peerExternalAddress,
    );
  }
}
