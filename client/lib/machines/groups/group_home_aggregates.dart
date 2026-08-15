// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import '../../models/group_active_author.dart';
import '../../models/message.dart';
import '../../models/profile_summary.dart';
import '../../services/profile_service.dart';
import '../../utils/date_format.dart';
import '../../utils/message_preview.dart';

/// Aggregati home derivati dallo storico archivio.
class GroupHomeAggregates {
  const GroupHomeAggregates({
    required this.activeAuthors,
    required this.conversationTile,
  });

  final List<GroupActiveAuthor> activeAuthors;
  final ChatPeer conversationTile;
}

/// Calcola autori attivi e tile conversazione dallo storico archivio.
Future<GroupHomeAggregates> buildGroupHomeAggregates({
  required List<ChatMessage> messages,
  required ProfileSummary profile,
  required String currentUserId,
  required ProfileService profileService,
}) async {
  final counts = <String, int>{};
  for (final message in messages) {
    final authorId = message.contentAuthorId ?? message.authorId;
    if (authorId == null || authorId == currentUserId) continue;
    counts[authorId] = (counts[authorId] ?? 0) + 1;
  }

  var activeAuthors = const <GroupActiveAuthor>[];
  if (counts.isNotEmpty) {
    final profiles =
        await profileService.fetchSummariesByIds(counts.keys.toList());
    final profilesById = {for (final profile in profiles) profile.id: profile};
    activeAuthors = counts.entries
        .map((entry) {
          final summary = profilesById[entry.key];
          if (summary == null) return null;
          return GroupActiveAuthor(
            profile: summary,
            messageCount: entry.value,
          );
        })
        .whereType<GroupActiveAuthor>()
        .toList()
      ..sort((a, b) => b.messageCount.compareTo(a.messageCount));
  }

  final conversationTile = buildGroupConversationTile(
    messages: messages,
    profile: profile,
  );

  return GroupHomeAggregates(
    activeAuthors: activeAuthors,
    conversationTile: conversationTile,
  );
}

/// Tile inbox gruppo — pura rispetto al profilo e ai messaggi.
ChatPeer buildGroupConversationTile({
  required List<ChatMessage> messages,
  required ProfileSummary profile,
}) {
  if (messages.isEmpty) {
    return ChatPeer.fromProfile(profile: profile);
  }

  final sorted = List<ChatMessage>.from(messages)
    ..sort(
      (a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
    );
  final last = sorted.last;
  final lastAt = last.createdAt;

  return ChatPeer(
    profile: profile,
    preview: inboxPreviewForMessage(last),
    timeLabel: formatConversationTime(lastAt),
    lastMessageAt: lastAt,
  );
}
