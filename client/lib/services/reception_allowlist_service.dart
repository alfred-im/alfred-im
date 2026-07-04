import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/allowed_person.dart';
import '../models/profile_summary.dart';

class ReceptionAllowlistService {
  ReceptionAllowlistService(this._client);

  final SupabaseClient _client;

  Future<List<AllowedPerson>> fetchAllowedPeople(String ownerId) async {
    final rows = await _client
        .from('reception_allowlist')
        .select(
          'id, allowed_profile_id, profiles:allowed_profile_id(id, username, display_name, avatar_url, pronouns)',
        )
        .eq('owner_id', ownerId)
        .order('created_at');

    return rows.map((row) {
      final profileJson = row['profiles'] as Map<String, dynamic>?;
      if (profileJson == null) {
        throw StateError('Profilo consentito mancante per ${row['id']}');
      }
      return AllowedPerson(
        entryId: row['id'] as String,
        profile: ProfileSummary.fromProfilesRow(profileJson),
      );
    }).toList();
  }

  Future<List<ProfileSummary>> searchProfiles(String query) async {
    if (query.trim().length < 2) return [];

    final rows = await _client.rpc(
      'search_profiles',
      params: {'p_query': query.trim(), 'p_limit': 20},
    );

    return (rows as List<dynamic>)
        .map((r) => ProfileSummary.fromProfilesRow(r as Map<String, dynamic>))
        .toList();
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
