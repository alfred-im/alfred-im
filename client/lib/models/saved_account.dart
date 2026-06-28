import 'profile_summary.dart';

class SavedAccount {
  const SavedAccount({
    required this.profile,
    required this.refreshToken,
  });

  final ProfileSummary profile;
  final String refreshToken;

  String get userId => profile.id;
  String get username => profile.username ?? '';
  String get displayName => profile.displayName;
  String? get avatarUrl => profile.avatarUrl;
  String? get pronouns => profile.pronouns;

  SavedAccount copyWith({
    ProfileSummary? profile,
    String? refreshToken,
  }) {
    return SavedAccount(
      profile: profile ?? this.profile,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  Map<String, dynamic> toJson() => {
        ...profile.toSavedAccountJsonFields(),
        'refreshToken': refreshToken,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      profile: ProfileSummary.fromSavedAccountJson(json),
      refreshToken: json['refreshToken'] as String,
    );
  }
}
