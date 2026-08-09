// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/contact.dart';
import '../../models/profile_summary.dart';

/// Effetti contacts → [ContactsController] e servizi collegati.
abstract class ContactsEffects {
  Future<void> loadContacts();

  Future<void> addInternal(ProfileSummary profile);

  Future<void> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  });

  Future<void> removeInternalByProfileId(String profileId);
}
