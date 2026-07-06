/// Tipo account Alfred (`profiles.profile_kind`).
enum ProfileKind {
  user,
  group;

  static ProfileKind fromString(String? value) {
    if (value == 'group') return ProfileKind.group;
    return ProfileKind.user;
  }

  String get wireValue => name;
}

/// Identità profilo Alfred visibile in UI (sidebar, inbox, chat, rubrica).
///
/// Unico modello per nome, username, avatar e pronomi — indipendente dal contesto
/// (account salvato, peer inbox, profilo completo).
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.pronouns,
    this.profileKind = ProfileKind.user,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? pronouns;
  final ProfileKind profileKind;

  bool get isGroup => profileKind == ProfileKind.group;

  bool get hasUsername => username != null && username!.isNotEmpty;

  bool get hasPronouns => pronouns != null && pronouns!.isNotEmpty;

  String get handle => hasUsername ? '@$username' : '';

  ProfileSummary copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? pronouns,
    ProfileKind? profileKind,
    bool clearAvatarUrl = false,
    bool clearPronouns = false,
    bool clearUsername = false,
  }) {
    return ProfileSummary(
      id: id,
      displayName: displayName ?? this.displayName,
      username: clearUsername ? null : username ?? this.username,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      pronouns: clearPronouns ? null : pronouns ?? this.pronouns,
      profileKind: profileKind ?? this.profileKind,
    );
  }

  /// Preferisce i campi non nulli di [other] per aggiornamenti parziali.
  ProfileSummary mergeDisplay(ProfileSummary other) {
    return copyWith(
      displayName: other.displayName,
      username: other.username ?? username,
      avatarUrl: other.avatarUrl ?? avatarUrl,
      pronouns: other.pronouns ?? pronouns,
    );
  }

  factory ProfileSummary.fromProfilesRow(Map<String, dynamic> json) {
    return ProfileSummary(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(json['profile_kind'] as String?),
    );
  }

  factory ProfileSummary.fromInboxRow(Map<String, dynamic> json) {
    return ProfileSummary(
      id: json['peer_profile_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['peer_avatar_url'] as String?,
      pronouns: json['peer_pronouns'] as String?,
    );
  }

  factory ProfileSummary.fromSavedAccountJson(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    return ProfileSummary(
      id: json['userId'] as String,
      username: username != null && username.isEmpty ? null : username,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(json['profileKind'] as String?),
    );
  }

  Map<String, dynamic> toSavedAccountJsonFields() => {
        'userId': id,
        'username': username ?? '',
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'pronouns': pronouns,
        'profileKind': profileKind.wireValue,
      };
}
