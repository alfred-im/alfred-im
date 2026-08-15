// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../machines/groups/group_home_aggregates.dart';
import '../machines/groups/groups_effects.dart';
import '../machines/groups/groups_machine.dart';
import '../models/chat_peer.dart';
import '../models/group_active_author.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';
import '../services/group_archive_cache.dart';
import '../services/profile_service.dart';
import '../utils/date_format.dart';

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
    required this._profileService,
    required this._archiveCache,
    required this._onStateChanged,
  }) {
    _machine = GroupHomeMachine(_LiveGroupHomeEffects._(this));
    unawaited(load());
  }

  final AccountSession _session;
  final ProfileSummary _profile;
  final ProfileService _profileService;
  final GroupArchiveCache _archiveCache;
  final void Function() _onStateChanged;
  late final GroupHomeMachine _machine;
  final GroupHomeUiState state = GroupHomeUiState();

  String get userId => _session.userId;

  Future<void> load() => _machine.send(const LoadGroupHome());

  Future<void> reload() => load();

  static String formatBirthDate(DateTime dateTime) =>
      formatProfileBirthDate(dateTime);

  void _applySnapshot(GroupHomeSnapshot snapshot) {
    state.createdAt = snapshot.createdAt;
    state.totalMessageCount = snapshot.totalMessageCount;
    state.activeAuthors = snapshot.activeAuthors;
    state.conversationTile = snapshot.conversationTile;
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
      }

      final messages = await _c._archiveCache.fetch();
      final aggregates = await buildGroupHomeAggregates(
        messages: messages,
        profile: _c._profile,
        currentUserId: _c.userId,
        profileService: _c._profileService,
      );

      final snapshot = GroupHomeSnapshot(
        createdAt: fullProfile?.createdAt,
        totalMessageCount: messages.length,
        activeAuthors: aggregates.activeAuthors,
        conversationTile: aggregates.conversationTile,
      );
      _c._applySnapshot(snapshot);
      _c.state.error = null;
      await _c._machine.send(GroupHomeLoaded(snapshot));
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const GroupHomeLoadFailed());
    } finally {
      _c._syncLoadingFromMachine();
      _c._notify();
    }
  }
}
