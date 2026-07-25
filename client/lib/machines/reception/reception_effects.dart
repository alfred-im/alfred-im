// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/allowed_person.dart';
import '../../models/profile_summary.dart';

/// Effetti reception → [ReceptionAllowlistController] e servizi collegati.
abstract class ReceptionEffects {
  Future<void> loadAllowlist();

  bool isProfileAllowed(String profileId);

  Future<void> addAllowedProfile(ProfileSummary profile);

  Future<void> removeAllowedPerson(AllowedPerson person);

  Future<void> removeByProfileId(String profileId);
}
