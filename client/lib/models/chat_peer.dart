// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../utils/avatar_color.dart';
import '../utils/date_format.dart';
import 'peer_relationship.dart';
import 'profile_summary.dart';

/// Controparte di una chat — identificata da [ProfileSummary] + metadati inbox.
class ChatPeer {
  const ChatPeer({
    required this.profile,
    this.address,
    this.preview = '',
    this.timeLabel = '',
    this.unreadCount = 0,
    this.lastMessageAt,
    this.avatarColor,
    this.relationship,
  });

  final ProfileSummary profile;
  final String? address;
  final String preview;
  final String timeLabel;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final Color? avatarColor;
  final PeerRelationship? relationship;

  String get profileId => profile.id;
  String get displayName => profile.displayName;
  String? get avatarUrl => profile.avatarUrl;
  String? get pronouns => profile.pronouns;

  bool get hasRelationship => relationship != null;

  bool get peerInContacts => relationship?.inContacts ?? false;

  bool get peerIsAllowed => relationship?.isAllowed ?? false;

  Color get resolvedAvatarColor =>
      avatarColor ?? avatarColorForId(profile.id);

  bool get hasInboxHistory => lastMessageAt != null;

  bool get isGroup => profile.isGroup;

  factory ChatPeer.fromInboxRow(Map<String, dynamic> json) {
    final lastAt = json['last_message_at'] != null
        ? DateTime.parse(json['last_message_at'] as String)
        : null;

    return ChatPeer(
      profile: ProfileSummary.fromInboxRow(json),
      preview: (json['last_message_preview'] as String?) ?? '',
      timeLabel: formatConversationTime(lastAt),
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageAt: lastAt,
      relationship: PeerRelationship.fromRow(json),
    );
  }

  factory ChatPeer.fromPeerContextRow(Map<String, dynamic> json) {
    return ChatPeer(
      profile: ProfileSummary.fromProfilesRow(json),
      address: json['username'] as String?,
      relationship: PeerRelationship.fromRow(json),
    );
  }

  factory ChatPeer.fromProfile({
    required ProfileSummary profile,
    String? address,
    PeerRelationship? relationship,
  }) {
    return ChatPeer(
      profile: profile,
      address: address,
      relationship: relationship,
    );
  }

  ChatPeer withRelationship(PeerRelationship relationship) {
    return ChatPeer(
      profile: profile,
      address: address,
      preview: preview,
      timeLabel: timeLabel,
      unreadCount: unreadCount,
      lastMessageAt: lastMessageAt,
      avatarColor: avatarColor,
      relationship: relationship,
    );
  }

  ChatPeer mergeFromInbox(ChatPeer inboxRow) {
    return ChatPeer(
      profile: profile.mergeDisplay(inboxRow.profile),
      address: address,
      preview: inboxRow.preview,
      timeLabel: inboxRow.timeLabel,
      unreadCount: inboxRow.unreadCount,
      lastMessageAt: inboxRow.lastMessageAt,
      avatarColor: avatarColor,
      relationship: inboxRow.relationship ?? relationship,
    );
  }
}
