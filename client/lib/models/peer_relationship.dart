// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Relazione viewer ↔ peer Alfred (rubrica e allow list).
class PeerRelationship {
  const PeerRelationship({
    required this.inContacts,
    required this.isAllowed,
    this.isDisabled = false,
  });

  final bool inContacts;
  final bool isAllowed;
  final bool isDisabled;

  factory PeerRelationship.fromRow(Map<String, dynamic> json) {
    return PeerRelationship(
      inContacts: json['peer_in_contacts'] as bool? ?? false,
      isAllowed: json['peer_is_allowed'] as bool? ?? false,
      isDisabled: json['peer_is_disabled'] as bool? ?? false,
    );
  }

  /// Null se la riga non include i flag (payload inbox legacy o peer senza RPC).
  static PeerRelationship? tryFromRow(Map<String, dynamic> json) {
    final hasContacts = json.containsKey('peer_in_contacts');
    final hasAllowed = json.containsKey('peer_is_allowed');
    if (!hasContacts && !hasAllowed) return null;
    return PeerRelationship.fromRow(json);
  }

  PeerRelationship copyWith({
    bool? inContacts,
    bool? isAllowed,
    bool? isDisabled,
  }) {
    return PeerRelationship(
      inContacts: inContacts ?? this.inContacts,
      isAllowed: isAllowed ?? this.isAllowed,
      isDisabled: isDisabled ?? this.isDisabled,
    );
  }
}
