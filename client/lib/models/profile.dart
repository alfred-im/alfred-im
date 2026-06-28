import 'profile_summary.dart';

class UserProfile {
  const UserProfile({
    required this.summary,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  final ProfileSummary summary;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get id => summary.id;
  String get username => summary.username ?? '';
  String get displayName => summary.displayName;
  String? get pronouns => summary.pronouns;
  String? get avatarUrl => summary.avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      summary: ProfileSummary.fromProfilesRow(json),
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
