// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../utils/avatar_color.dart';
import '../utils/date_format.dart';
import 'peer_relationship.dart';
import 'profile_summary.dart';

/// Controparte di una chat — identificata da [peerAddress] + metadati inbox.
class ChatPeer {
  const ChatPeer({
    required this.peerAddress,
    this.profile,
    this.preview = '',
    this.timeLabel = '',
    this.unreadCount = 0,
    this.lastMessageAt,
    this.avatarColor,
    this.relationship,
  });

  /// Chiave canonica conversazione — lowercase `username` o `user@server`.
  final String peerAddress;

  /// Presentazione profilo — opzionale; arricchita via `get_profiles`.
  final ProfileSummary? profile;

  final String preview;
  final String timeLabel;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final Color? avatarColor;
  final PeerRelationship? relationship;

  /// UUID profilo locale — solo cache; non chiave conversazione.
  String? get profileId => profile?.id;

  String get displayName => profile?.displayName ?? peerAddress;

  String? get avatarUrl => profile?.avatarUrl;

  String? get pronouns => profile?.pronouns;

  bool get hasRelationship => relationship != null;

  bool get peerInContacts => relationship?.inContacts ?? false;

  bool get peerIsAllowed => relationship?.isAllowed ?? false;

  bool get peerIsDisabled => relationship?.isDisabled ?? false;

  Color get resolvedAvatarColor =>
      avatarColor ?? avatarColorForId(profile?.id ?? peerAddress);

  bool get hasInboxHistory => lastMessageAt != null;

  bool get isGroup => profile?.isGroup ?? false;

  factory ChatPeer.fromInboxRow(Map<String, dynamic> json) {
    final peerAddress =
        (json['peer_address'] as String).trim().toLowerCase();
    final lastAt = json['last_message_at'] != null
        ? DateTime.parse(json['last_message_at'] as String)
        : null;

    return ChatPeer(
      peerAddress: peerAddress,
      profile: ProfileSummary.fromInboxRow(json),
      preview: (json['last_message_preview'] as String?) ?? '',
      timeLabel: formatConversationTime(lastAt),
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageAt: lastAt,
      relationship: PeerRelationship.tryFromRow(json),
    );
  }

  factory ChatPeer.fromPeerContextRow(Map<String, dynamic> json) {
    final username = (json['username'] as String?)?.trim().toLowerCase();
    final address = username ?? '';
    return ChatPeer(
      peerAddress: address,
      profile: ProfileSummary.fromProfilesRow(json).copyWith(address: address),
      relationship: PeerRelationship.fromRow(json),
    );
  }

  factory ChatPeer.fromProfile({
    required String peerAddress,
    ProfileSummary? profile,
    PeerRelationship? relationship,
  }) {
    final normalized = peerAddress.trim().toLowerCase();
    return ChatPeer(
      peerAddress: normalized,
      profile: profile?.copyWith(address: profile.address ?? normalized) ??
          ProfileSummary.fromAddress(normalized),
      relationship: relationship,
    );
  }

  factory ChatPeer.fromAddress(String address) {
    final normalized = address.trim().toLowerCase();
    return ChatPeer(
      peerAddress: normalized,
      profile: ProfileSummary.fromAddress(normalized),
    );
  }

  ChatPeer withRelationship(PeerRelationship relationship) {
    return ChatPeer(
      peerAddress: peerAddress,
      profile: profile,
      preview: preview,
      timeLabel: timeLabel,
      unreadCount: unreadCount,
      lastMessageAt: lastMessageAt,
      avatarColor: avatarColor,
      relationship: relationship,
    );
  }

  ChatPeer mergeFromInbox(ChatPeer inboxRow) {
    if (inboxRow.peerAddress != peerAddress) return this;
    return ChatPeer(
      peerAddress: peerAddress,
      profile: profile?.mergeDisplay(inboxRow.profile ?? ProfileSummary.fromAddress(peerAddress)) ??
          inboxRow.profile,
      preview: inboxRow.preview,
      timeLabel: inboxRow.timeLabel,
      unreadCount: inboxRow.unreadCount,
      lastMessageAt: inboxRow.lastMessageAt,
      avatarColor: avatarColor,
      relationship: inboxRow.relationship ?? relationship,
    );
  }

  ChatPeer mergeProfile(ProfileSummary enriched) {
    return ChatPeer(
      peerAddress: peerAddress,
      profile: (profile ?? ProfileSummary.fromAddress(peerAddress))
          .mergeDisplay(enriched),
      preview: preview,
      timeLabel: timeLabel,
      unreadCount: unreadCount,
      lastMessageAt: lastMessageAt,
      avatarColor: avatarColor,
      relationship: relationship,
    );
  }

  bool matchesAddress(String other) =>
      peerAddress == other.trim().toLowerCase();
}
