// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Relazione viewer ↔ peer Alfred (rubrica e allow list).
class PeerRelationship {
  const PeerRelationship({
    required this.inContacts,
    required this.isAllowed,
  });

  final bool inContacts;
  final bool isAllowed;

  factory PeerRelationship.fromRow(Map<String, dynamic> json) {
    return PeerRelationship(
      inContacts: json['peer_in_contacts'] as bool? ?? false,
      isAllowed: json['peer_is_allowed'] as bool? ?? false,
    );
  }

  /// Null when the row has no relationship flags (legacy inbox payload).
  static PeerRelationship? tryFromRow(Map<String, dynamic> json) {
    final hasContacts = json.containsKey('peer_in_contacts');
    final hasAllowed = json.containsKey('peer_is_allowed');
    if (!hasContacts && !hasAllowed) return null;
    return PeerRelationship.fromRow(json);
  }

  PeerRelationship copyWith({
    bool? inContacts,
    bool? isAllowed,
  }) {
    return PeerRelationship(
      inContacts: inContacts ?? this.inContacts,
      isAllowed: isAllowed ?? this.isAllowed,
    );
  }
}
