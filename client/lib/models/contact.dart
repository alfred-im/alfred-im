enum ContactProtocol { internal, xmpp, matrix }

ContactProtocol contactProtocolFromString(String value) {
  return ContactProtocol.values.firstWhere(
    (p) => p.name == value,
    orElse: () => ContactProtocol.internal,
  );
}

class Contact {
  const Contact({
    required this.id,
    required this.ownerId,
    required this.protocol,
    this.linkedProfileId,
    this.externalAddress,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final ContactProtocol protocol;
  final String? linkedProfileId;
  final String? externalAddress;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      protocol: contactProtocolFromString(json['protocol'] as String),
      linkedProfileId: json['linked_profile_id'] as String?,
      externalAddress: json['external_address'] as String?,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

}

class ProfileSearchResult {
  const ProfileSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    return ProfileSearchResult(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
