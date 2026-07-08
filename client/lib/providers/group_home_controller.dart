import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_peer.dart';
import '../models/group_active_author.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';
import '../utils/date_format.dart';
import '../utils/message_preview.dart';

/// Stato home account gruppo — riepilogo, autori attivi, tile conversazione.
class GroupHomeController extends ChangeNotifier {
  GroupHomeController({
    required this.session,
    required this.profile,
    required this.messageService,
    required this.profileService,
  }) {
    unawaited(load());
  }

  final AccountSession session;
  final ProfileSummary profile;
  final MessageService messageService;
  final ProfileService profileService;

  DateTime? createdAt;
  int totalMessageCount = 0;
  List<GroupActiveAuthor> activeAuthors = [];
  ChatPeer? conversationTile;
  bool isLoading = true;
  String? error;

  String get userId => session.userId;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final fullProfile = session.fullProfile ?? await session.fetchFullProfile();
      if (fullProfile != null) {
        session.fullProfile = fullProfile;
        createdAt = fullProfile.createdAt;
      }

      final messages = await messageService.fetchOwnerMessages(
        currentUserId: userId,
      );
      totalMessageCount = messages.length;
      activeAuthors = await _buildActiveAuthors(messages);
      conversationTile = _buildConversationTile(messages);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load();

  Future<List<GroupActiveAuthor>> _buildActiveAuthors(
    List<ChatMessage> messages,
  ) async {
    final counts = <String, int>{};
    for (final message in messages) {
      final authorId = message.contentAuthorId ?? message.authorId;
      if (authorId == null || authorId == userId) continue;
      counts[authorId] = (counts[authorId] ?? 0) + 1;
    }

    if (counts.isEmpty) return const [];

    final profiles = await profileService.fetchSummariesByIds(counts.keys.toList());
    final profilesById = {for (final p in profiles) p.id: p};

    final authors = counts.entries
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

    return authors;
  }

  ChatPeer _buildConversationTile(List<ChatMessage> messages) {
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

  static String formatBirthDate(DateTime dateTime) {
    const months = [
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    final local = dateTime.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
