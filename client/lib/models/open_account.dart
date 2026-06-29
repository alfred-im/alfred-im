import 'profile_summary.dart';

/// Account messaggistica Alfred **aperto** nell'app (sessione viva, non bookmark).
class OpenAccount {
  const OpenAccount({
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

  OpenAccount copyWith({
    ProfileSummary? profile,
    String? refreshToken,
  }) {
    return OpenAccount(
      profile: profile ?? this.profile,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  Map<String, dynamic> toJson() => {
        ...profile.toSavedAccountJsonFields(),
        'refreshToken': refreshToken,
      };

  factory OpenAccount.fromJson(Map<String, dynamic> json) {
    return OpenAccount(
      profile: ProfileSummary.fromSavedAccountJson(json),
      refreshToken: json['refreshToken'] as String,
    );
  }
}
