// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'profile_summary.dart';

class Contact {
  const Contact({
    required this.id,
    required this.archiveUserId,
    this.linkedProfileId,
    this.externalAddress,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String archiveUserId;
  final String? linkedProfileId;
  final String? externalAddress;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Contatto su profilo Alfred locale (stessa istanza).
  bool get isLocal => linkedProfileId != null;

  /// Contatto salvato come indirizzo federato `user@server`.
  bool get isFederated => externalAddress != null;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      archiveUserId: json['archive_user_id'] as String,
      linkedProfileId: json['linked_profile_id'] as String?,
      externalAddress: json['external_address'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ProfileSummary? get internalProfileSummary {
    if (!isLocal) return null;
    final profileId = linkedProfileId;
    if (profileId == null) return null;
    return ProfileSummary(
      id: profileId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}
