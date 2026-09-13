// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

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

final class AddContactByAddress extends ContactsEvent {
  const AddContactByAddress(this.address);
  final String address;
}

final class RemoveContactByAddress extends ContactsEvent {
  const RemoveContactByAddress(this.address);
  final String address;
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
      case AddContactByAddress(:final address):
        await _effects.addByAddress(address);
        await send(const LoadContacts());
      case RemoveContactByAddress(:final address):
        await _effects.removeByAddress(address);
        await send(const LoadContacts());
    }
  }
}
