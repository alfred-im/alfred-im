// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Tipo account Alfred (`profiles.profile_kind`).
enum ProfileKind {
  user,
  group,
  owner;

  static ProfileKind fromString(String? value) {
    switch (value) {
      case 'group':
        return ProfileKind.group;
      case 'owner':
        return ProfileKind.owner;
      default:
        return ProfileKind.user;
    }
  }

  String get wireValue => name;
}

/// Identità profilo Alfred visibile in UI (sidebar, inbox, chat, rubrica).
///
/// Chiave presentazione: [address] quando nota; [id] opzionale — solo cache locale.
class ProfileSummary {
  const ProfileSummary({
    this.id,
    required this.displayName,
    this.address,
    this.username,
    this.avatarUrl,
    this.coverUrl,
    this.pronouns,
    this.profileKind = ProfileKind.user,
  });

  /// UUID profilo locale — opzionale; non usato come chiave conversazione.
  final String? id;

  final String displayName;

  /// Indirizzo canonico lowercase (`username` o `user@server`).
  final String? address;

  final String? username;
  final String? avatarUrl;
  final String? coverUrl;
  final String? pronouns;
  final ProfileKind profileKind;

  bool get isGroup => profileKind == ProfileKind.group;

  bool get isOwner => profileKind == ProfileKind.owner;

  /// Account con inbox personale (user e owner; non gruppo).
  bool get hasPersonalInbox => !isGroup;

  bool get hasUsername => username != null && username!.isNotEmpty;

  bool get hasAddress => address != null && address!.isNotEmpty;

  bool get hasPronouns => pronouns != null && pronouns!.isNotEmpty;

  String get handle => hasUsername ? '@$username' : '';

  /// Chiave presentazione per batch `get_profiles` e fallback UI.
  String get presentationKey => address ?? username ?? id ?? displayName;

  /// Indirizzo canonico peer per inbox, chat e allow list.
  String get resolvedPeerAddress {
    final value = address ?? username;
    if (value != null && value.isNotEmpty) return value.trim().toLowerCase();
    if (id != null && id!.isNotEmpty) return id!;
    return displayName.trim().toLowerCase();
  }

  ProfileSummary copyWith({
    String? id,
    String? displayName,
    String? address,
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? pronouns,
    ProfileKind? profileKind,
    bool clearId = false,
    bool clearAddress = false,
    bool clearAvatarUrl = false,
    bool clearCoverUrl = false,
    bool clearPronouns = false,
    bool clearUsername = false,
  }) {
    return ProfileSummary(
      id: clearId ? null : id ?? this.id,
      displayName: displayName ?? this.displayName,
      address: clearAddress ? null : address ?? this.address,
      username: clearUsername ? null : username ?? this.username,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      coverUrl: clearCoverUrl ? null : coverUrl ?? this.coverUrl,
      pronouns: clearPronouns ? null : pronouns ?? this.pronouns,
      profileKind: profileKind ?? this.profileKind,
    );
  }

  /// Preferisce i campi non nulli di [other] per aggiornamenti parziali.
  ProfileSummary mergeDisplay(ProfileSummary other) {
    return copyWith(
      displayName: other.displayName,
      address: other.address ?? address,
      username: other.username ?? username,
      avatarUrl: other.avatarUrl ?? avatarUrl,
      coverUrl: other.coverUrl ?? coverUrl,
      pronouns: other.pronouns ?? pronouns,
      profileKind: other.profileKind,
      id: other.id ?? id,
    );
  }

  factory ProfileSummary.fromProfilesRow(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    return ProfileSummary(
      id: json['id'] as String?,
      username: username,
      address: username?.trim().toLowerCase(),
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(json['profile_kind'] as String?),
    );
  }

  factory ProfileSummary.fromGetProfilesRow(Map<String, dynamic> json) {
    final address = (json['address'] as String).trim().toLowerCase();
    final at = address.lastIndexOf('@');
    final bareUsername = at > 0 ? address.substring(0, at) : address;
    return ProfileSummary(
      address: address,
      username: at > 0 ? bareUsername : address,
      displayName: (json['display_name'] as String?) ?? address,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(json['profile_kind'] as String?),
    );
  }

  factory ProfileSummary.fromInboxRow(Map<String, dynamic> json) {
    final peerAddress =
        (json['peer_address'] as String).trim().toLowerCase();
    final at = peerAddress.lastIndexOf('@');
    final bareUsername = at > 0 ? peerAddress.substring(0, at) : peerAddress;
    return ProfileSummary(
      address: peerAddress,
      username: bareUsername,
      displayName: (json['display_name'] as String?) ?? peerAddress,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(
        json['profile_kind'] as String?,
      ),
    );
  }

  factory ProfileSummary.fromAddress(String address) {
    final normalized = address.trim().toLowerCase();
    final at = normalized.lastIndexOf('@');
    final bareUsername = at > 0 ? normalized.substring(0, at) : normalized;
    return ProfileSummary(
      address: normalized,
      username: bareUsername,
      displayName: normalized,
    );
  }

  factory ProfileSummary.fromSavedAccountJson(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    final normalizedUsername =
        username != null && username.isNotEmpty ? username.trim().toLowerCase() : null;
    return ProfileSummary(
      id: json['userId'] as String,
      username: normalizedUsername,
      address: normalizedUsername,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      pronouns: json['pronouns'] as String?,
      profileKind: ProfileKind.fromString(json['profileKind'] as String?),
    );
  }

  Map<String, dynamic> toSavedAccountJsonFields() => {
        'userId': id,
        'username': username ?? '',
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'coverUrl': coverUrl,
        'pronouns': pronouns,
        'profileKind': profileKind.wireValue,
      };
}
