// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../machines/groups/groups_machine.dart';
import '../models/chat_peer.dart';
import '../models/group_active_author.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';
import '../utils/date_format.dart';
import '../utils/message_preview.dart';

/// Stato home gruppo esposto alla UI tramite [GroupHomeController].
class GroupHomeUiState {
  DateTime? createdAt;
  int totalMessageCount = 0;
  List<GroupActiveAuthor> activeAuthors = [];
  ChatPeer? conversationTile;
  bool isLoading = true;
  String? error;
}

/// Orchestrazione load home account gruppo.
class GroupHomeCoordinator {
  GroupHomeCoordinator({
    required this._session,
    required this._profile,
    required this._messageService,
    required this._profileService,
    required this._onStateChanged,
  }) {
    _machine = GroupHomeMachine(_LiveGroupHomeEffects._(this));
    unawaited(load());
  }

  final AccountSession _session;
  final ProfileSummary _profile;
  final MessageService _messageService;
  final ProfileService _profileService;
  final void Function() _onStateChanged;
  late final GroupHomeMachine _machine;
  final GroupHomeUiState state = GroupHomeUiState();

  GroupHomeMachine get machine => _machine;

  String get userId => _session.userId;

  Future<void> load() => _machine.send(const LoadGroupHome());

  Future<void> reload() => load();

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

  void _syncLoadingFromMachine() {
    state.isLoading = _machine.loadState == GroupHomeLoadState.loading;
  }

  void _notify() => _onStateChanged();
}

class _LiveGroupHomeEffects implements GroupHomeEffects {
  _LiveGroupHomeEffects._(this._coordinator);

  final GroupHomeCoordinator _coordinator;

  GroupHomeCoordinator get _c => _coordinator;

  @override
  Future<void> loadHome() async {
    _c.state.error = null;
    try {
      final fullProfile =
          _c._session.fullProfile ?? await _c._session.fetchFullProfile();
      if (fullProfile != null) {
        _c._session.fullProfile = fullProfile;
        _c.state.createdAt = fullProfile.createdAt;
      }

      final messages = await _c._messageService.fetchOwnerMessages(
        currentUserId: _c.userId,
      );
      _c.state.totalMessageCount = messages.length;
      _c.state.activeAuthors = await _buildActiveAuthors(messages);
      _c.state.conversationTile = _buildConversationTile(messages);
      _c.state.error = null;
      await _c._machine.send(const GroupHomeLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const GroupHomeLoadFailed());
    } finally {
      _c._syncLoadingFromMachine();
      _c._notify();
    }
  }

  Future<List<GroupActiveAuthor>> _buildActiveAuthors(
    List<ChatMessage> messages,
  ) async {
    final counts = <String, int>{};
    for (final message in messages) {
      final authorId = message.contentAuthorId ?? message.authorId;
      if (authorId == null || authorId == _c.userId) continue;
      counts[authorId] = (counts[authorId] ?? 0) + 1;
    }

    if (counts.isEmpty) return const [];

    final profiles =
        await _c._profileService.fetchSummariesByIds(counts.keys.toList());
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
      return ChatPeer.fromProfile(profile: _c._profile);
    }

    final sorted = List<ChatMessage>.from(messages)
      ..sort(
        (a, b) =>
            (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
      );
    final last = sorted.last;
    final lastAt = last.createdAt;

    return ChatPeer(
      profile: _c._profile,
      preview: inboxPreviewForMessage(last),
      timeLabel: formatConversationTime(lastAt),
      lastMessageAt: lastAt,
    );
  }
}
