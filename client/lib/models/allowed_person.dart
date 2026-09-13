// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'profile_summary.dart';

/// Voce nella lista persone consentite in ricezione.
class AllowedPerson {
  const AllowedPerson({
    required this.entryId,
    required this.allowedAddress,
    this.profile,
  });

  final String entryId;

  /// Indirizzo canonico lowercase consentito in ricezione.
  final String allowedAddress;

  /// Presentazione profilo — opzionale; arricchita via `get_profiles`.
  final ProfileSummary? profile;

  String get displayName => profile?.displayName ?? allowedAddress;
}
