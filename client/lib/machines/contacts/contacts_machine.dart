// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/contact.dart';
import '../../models/profile_summary.dart';
import 'contacts_effects.dart';

/// Stato caricamento — `docs/model/uml/contacts/contacts-state.puml`.
enum ContactsLoadState {
  loading,
  ready,
}

/// Eventi — `docs/domain/contacts/commands-and-events.md`.
sealed class ContactsEvent {
  const ContactsEvent();
}

final class LoadContacts extends ContactsEvent {
  const LoadContacts();
}

final class ContactsLoaded extends ContactsEvent {
  const ContactsLoaded();
}

final class ContactsLoadFailed extends ContactsEvent {
  const ContactsLoadFailed();
}

final class SetSearchQuery extends ContactsEvent {
  const SetSearchQuery(this.query);
  final String query;
}

final class AddInternalContact extends ContactsEvent {
  const AddInternalContact(this.profile);
  final ProfileSummary profile;
}

final class AddExternalContact extends ContactsEvent {
  const AddExternalContact({
    required this.protocol,
    required this.address,
    required this.displayName,
  });
  final ContactProtocol protocol;
  final String address;
  final String displayName;
}

final class RemoveInternalContact extends ContactsEvent {
  const RemoveInternalContact(this.profileId);
  final String profileId;
}

/// Interprete statechart contacts — allineato a UML.
///
/// Produzione: [ContactsCoordinator] + [ContactsController].
class ContactsMachine {
  ContactsMachine(this._effects);

  final ContactsEffects _effects;

  ContactsLoadState loadState = ContactsLoadState.loading;
  String searchQuery = '';

  Future<void> send(ContactsEvent event) async {
    switch (event) {
      case LoadContacts():
        loadState = ContactsLoadState.loading;
        await _effects.loadContacts();
      case ContactsLoaded():
        loadState = ContactsLoadState.ready;
      case ContactsLoadFailed():
        loadState = ContactsLoadState.ready;
      case SetSearchQuery(:final query):
        searchQuery = query;
        _effects.onSearchQueryChanged(query);
      case AddInternalContact(:final profile):
        await _effects.addInternal(profile);
        await send(const LoadContacts());
      case AddExternalContact(:final protocol, :final address, :final displayName):
        await _effects.addExternal(
          protocol: protocol,
          address: address,
          displayName: displayName,
        );
        await send(const LoadContacts());
      case RemoveInternalContact(:final profileId):
        await _effects.removeInternalByProfileId(profileId);
        await send(const LoadContacts());
    }
  }
}
