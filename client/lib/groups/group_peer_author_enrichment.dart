// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/profile_service.dart';
import '../utils/author_display.dart' show enrichMessageAuthor;

/// Enriches peer-group chat messages with author display names and avatars.
class GroupPeerAuthorEnrichment {
  GroupPeerAuthorEnrichment({
    required this.profileService,
    required this.userId,
  });

  final ProfileService profileService;
  final String userId;

  Future<List<ChatMessage>> enrichMessages(List<ChatMessage> source) async {
    final authorIds = source
        .map((m) => m.contentAuthorId ?? m.authorId)
        .whereType<String>()
        .where((id) => id != userId)
        .toSet()
        .toList();

    var profilesById = <String, ProfileSummary>{};
    if (authorIds.isNotEmpty) {
      final profiles = await profileService.fetchSummariesByIds(authorIds);
      profilesById = {for (final p in profiles) p.id: p};
    }

    return source
        .map(
          (m) => enrichMessageAuthor(
            message: m,
            profilesById: profilesById,
            currentUserId: userId,
          ),
        )
        .toList();
  }
}
