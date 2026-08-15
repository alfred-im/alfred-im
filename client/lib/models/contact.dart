// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'profile_summary.dart';

enum ContactProtocol { internal, xmpp, matrix }

ContactProtocol contactProtocolFromString(String value) {
  return ContactProtocol.values.firstWhere(
    (p) => p.name == value,
    orElse: () => ContactProtocol.internal,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.archiveUserId,
    required this.protocol,
    this.linkedProfileId,
    this.externalAddress,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String archiveUserId;
  final ContactProtocol protocol;
  final String? linkedProfileId;
  final String? externalAddress;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      archiveUserId: json['archive_user_id'] as String,
      protocol: contactProtocolFromString(json['protocol'] as String),
      linkedProfileId: json['linked_profile_id'] as String?,
      externalAddress: json['external_address'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Profilo Alfred collegato, se contatto interno con `linkedProfileId`.
  ProfileSummary? get internalProfileSummary {
    if (protocol != ContactProtocol.internal) return null;
    final profileId = linkedProfileId;
    if (profileId == null) return null;
    return ProfileSummary(
      id: profileId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}
