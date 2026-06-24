class SavedAccount {
  const SavedAccount({
    required this.userId,
    required this.email,
    required this.refreshToken,
    required this.displayName,
  });

  final String userId;
  final String email;
  final String refreshToken;
  final String displayName;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'refreshToken': refreshToken,
        'displayName': displayName,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      userId: json['userId'] as String,
      email: json['email'] as String,
      refreshToken: json['refreshToken'] as String,
      displayName: json['displayName'] as String,
    );
  }
}
