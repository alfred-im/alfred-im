// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Voce rubrica — solo indirizzo lowercase (`username` o `user@server`).
class Contact {
  const Contact({
    required this.id,
    required this.archiveUserId,
    required this.address,
    required this.createdAt,
  });

  final String id;
  final String archiveUserId;

  /// Indirizzo canonico lowercase.
  final String address;

  final DateTime createdAt;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      archiveUserId: json['archive_user_id'] as String,
      address: (json['address'] as String).trim().toLowerCase(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
