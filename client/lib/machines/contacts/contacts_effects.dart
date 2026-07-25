// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../coordinators/contacts_coordinator.dart';
import '../../models/contact.dart';
import '../../models/profile_summary.dart';
import 'contacts_machine.dart';

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

/// Implementazione produzione collegata a [ContactsCoordinator].
class LiveContactsEffects implements ContactsEffects {
  LiveContactsEffects(this._coordinator);

  final ContactsCoordinator _coordinator;

  ContactsCoordinator get _c => _coordinator;

  @override
  Future<void> loadContacts() async {
    try {
      _c.state.contacts =
          await _c.contactService.fetchContacts(_c.ownerId);
      _c.state.error = null;
      await _c.machine.send(const ContactsLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c.machine.send(const ContactsLoadFailed());
    } finally {
      _c.syncLoadingFromMachine();
      _c.notifyStateChanged();
    }
  }

  @override
  Future<void> addInternal(ProfileSummary profile) async {
    await _c.contactService.addInternalContact(
      ownerId: _c.ownerId,
      profile: profile,
    );
  }

  @override
  Future<void> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  }) async {
    await _c.contactService.addExternalContact(
      ownerId: _c.ownerId,
      protocol: protocol,
      externalAddress: address,
      displayName: displayName,
    );
  }

  @override
  Future<void> removeInternalByProfileId(String profileId) async {
    final contact = _c.contactForProfileId(profileId);
    if (contact == null) return;
    await _c.contactService.deleteContact(contact.id);
  }
}
