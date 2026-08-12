// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_peer.dart';
import '../models/profile.dart';
import '../models/profile_summary.dart';

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  static const _publicProfileColumns =
      'id, username, display_name, avatar_url, cover_url, pronouns, profile_kind';

  static String? normalizeOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
    String? coverUrl,
    bool clearCoverUrl = false,
  }) async {
    final row = await _client
        .from('profiles')
        .update({
          'display_name': displayName.trim(),
          'bio': normalizeOptional(bio),
          'pronouns': normalizeOptional(pronouns),
          'avatar_url': avatarUrl,
          'cover_url': clearCoverUrl ? null : coverUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromJson(row);
  }

  Future<ProfileSummary?> findByUsername(String username) async {
    final peer = await findPeerByUsername(username);
    return peer?.profile;
  }

  Future<ChatPeer?> findPeerByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.length < 3) return null;

    final row = await _client.rpc(
      'find_profile_by_username',
      params: {'p_username': normalized},
    );

    if (row == null) return null;
    if (row is List) {
      if (row.isEmpty) return null;
      return ChatPeer.fromPeerContextRow(row.first as Map<String, dynamic>);
    }
    return ChatPeer.fromPeerContextRow(row as Map<String, dynamic>);
  }

  Future<ChatPeer?> getPeerContext(String profileId) async {
    final row = await _client.rpc(
      'get_peer_context',
      params: {'p_peer_profile_id': profileId},
    );

    if (row == null) return null;
    if (row is List) {
      if (row.isEmpty) return null;
      return ChatPeer.fromPeerContextRow(row.first as Map<String, dynamic>);
    }
    return ChatPeer.fromPeerContextRow(row as Map<String, dynamic>);
  }

  Future<List<ProfileSummary>> fetchSummariesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select(_publicProfileColumns)
        .inFilter('id', ids);

    return rows
        .map((row) => ProfileSummary.fromProfilesRow(row))
        .toList();
  }

  Future<ProfileSummary?> findById(String profileId) async {
    final summaries = await fetchSummariesByIds([profileId]);
    if (summaries.isEmpty) return null;
    return summaries.first;
  }
}
