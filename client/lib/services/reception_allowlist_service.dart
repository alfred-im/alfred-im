// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import 'profile_search_service.dart';

class ReceptionAllowlistService {
  ReceptionAllowlistService(this._client)
      : _profileSearch = ProfileSearchService(_client);

  final SupabaseClient _client;
  final ProfileSearchService _profileSearch;

  Future<List<AllowedPerson>> fetchAllowedPeople(String ownerId) async {
    final rows = await _client
        .from('reception_allowlist')
        .select(
          'id, allowed_profile_id, profiles:allowed_profile_id(id, username, display_name, avatar_url, pronouns)',
        )
        .eq('owner_id', ownerId)
        .order('created_at');

    final people = rows.map((row) {
      final profileJson = row['profiles'] as Map<String, dynamic>?;
      if (profileJson == null) {
        throw StateError('Profilo consentito mancante per ${row['id']}');
      }
      return AllowedPerson(
        entryId: row['id'] as String,
        profile: ProfileSummary.fromProfilesRow(profileJson),
      );
    }).toList();

    people.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    return people;
  }

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _profileSearch.searchProfiles(query);
  }

  Future<AllowedPerson> addAllowedProfile({
    required String ownerId,
    required ProfileSummary profile,
  }) async {
    final row = await _client
        .from('reception_allowlist')
        .insert({
          'owner_id': ownerId,
          'allowed_profile_id': profile.id,
        })
        .select(
          'id, allowed_profile_id, profiles:allowed_profile_id(id, username, display_name, avatar_url, pronouns)',
        )
        .single();

    final profileJson = row['profiles'] as Map<String, dynamic>;
    return AllowedPerson(
      entryId: row['id'] as String,
      profile: ProfileSummary.fromProfilesRow(profileJson),
    );
  }

  Future<void> removeAllowedPerson(String entryId) async {
    await _client.from('reception_allowlist').delete().eq('id', entryId);
  }
}
