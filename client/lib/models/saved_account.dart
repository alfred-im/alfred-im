import '../utils/auth_identity.dart';

class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.username,
    required this.refreshToken,
    required this.displayName,
  });

  final String userId;
  final String username;
  final String refreshToken;
  final String displayName;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'refreshToken': refreshToken,
        'displayName': displayName,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String? ??
        _legacyUsernameFromJson(json['email'] as String?);
    return SavedAccount(
      userId: json['userId'] as String,
      username: username,
      refreshToken: json['refreshToken'] as String,
      displayName: json['displayName'] as String,
    );
  }

  static String _legacyUsernameFromJson(String? legacyEmail) {
    if (legacyEmail == null || legacyEmail.isEmpty) return '';
    return AuthIdentity.usernameFromAuthEmail(legacyEmail) ??
        legacyEmail.split('@').first;
  }
}
