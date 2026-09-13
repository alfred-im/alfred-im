// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/allowed_person.dart';

/// Effetti reception → [ReceptionAllowlistController] e servizi collegati.
abstract class ReceptionEffects {
  Future<void> loadAllowlist();

  bool isAddressAllowed(String address);

  Future<void> addAllowedAddress(String address);

  Future<void> removeAllowedPerson(AllowedPerson person);

  Future<void> removeByAddress(String address);
}
