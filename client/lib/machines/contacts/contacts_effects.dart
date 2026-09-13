// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Effetti contacts → [ContactsController] e servizi collegati.
abstract class ContactsEffects {
  Future<void> loadContacts();

  Future<void> addByAddress(String address);

  Future<void> removeByAddress(String address);
}
