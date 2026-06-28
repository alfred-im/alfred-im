import '../models/profile.dart';
import '../models/profile_summary.dart';
import 'supabase_bootstrap.dart';

class ProfileService {
  static const _publicProfileColumns =
      'id, username, display_name, avatar_url, pronouns';

  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
  }) async {
    final row = await supabase
        .from('profiles')
        .update({
          'display_name': displayName,
          'bio': bio,
          'pronouns': pronouns,
          'avatar_url': ?avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromJson(row);
  }

  Future<ProfileSummary?> findByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.length < 3) return null;

    final row = await supabase.rpc(
      'find_profile_by_username',
      params: {'p_username': normalized},
    );

    if (row == null) return null;
    if (row is List) {
      if (row.isEmpty) return null;
      return ProfileSummary.fromProfilesRow(row.first as Map<String, dynamic>);
    }
    return ProfileSummary.fromProfilesRow(row as Map<String, dynamic>);
  }

  Future<List<ProfileSummary>> fetchSummariesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final rows = await supabase
        .from('profiles')
        .select(_publicProfileColumns)
        .inFilter('id', ids);

    return rows
        .map((row) => ProfileSummary.fromProfilesRow(row))
        .toList();
  }
}
