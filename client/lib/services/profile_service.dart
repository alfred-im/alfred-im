import '../models/profile.dart';
import 'supabase_bootstrap.dart';

class ProfileService {
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    String? bio,
  }) async {
    final row = await supabase
        .from('profiles')
        .update({
          'display_name': displayName,
          'bio': bio,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromJson(row);
  }

  Future<UserProfile?> getProfile(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }
}
