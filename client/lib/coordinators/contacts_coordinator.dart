// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../machines/contacts/contacts_effects.dart';
import '../machines/contacts/contacts_machine.dart';
import '../models/contact.dart';
import '../models/profile_summary.dart';
import '../services/contact_service.dart';
import '../utils/list_filter.dart';

/// Stato contacts esposto alla UI tramite [ContactsController].
class ContactsState {
  List<Contact> contacts = [];
  bool isLoading = false;
  String? error;
}

/// Orchestrazione load, filtro e CRUD rubrica.
class ContactsCoordinator {
  ContactsCoordinator({
    required this.focusUserId,
    required this._contactService,
    required this._onStateChanged,
  }) {
    _machine = ContactsMachine(_LiveContactsEffects(this));
  }

  final String focusUserId;
  final ContactService _contactService;
  final void Function() _onStateChanged;
  late final ContactsMachine _machine;
  final ContactsState state = ContactsState();

  ContactService get contactService => _contactService;

  void syncLoadingFromMachine() => _syncLoadingFromMachine();

  void notifyStateChanged() => _notify();

  List<Contact> get filteredContacts => filterByQuery(
        state.contacts,
        _machine.searchQuery,
        (contact) => contact.address,
      );

  Contact? contactForAddress(String address) {
    final normalized = address.trim().toLowerCase();
    for (final contact in state.contacts) {
      if (contact.address == normalized) return contact;
    }
    return null;
  }

  void setSearchQuery(String value) {
    unawaited(_machine.send(SetSearchQuery(value)));
    _syncLoadingFromMachine();
    _notify();
  }

  Future<void> load() => _machine.send(const LoadContacts());

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _contactService.searchProfiles(query);
  }

  Future<Contact> addByAddress(String address) async {
    await _machine.send(AddContactByAddress(address));
    return contactForAddress(address) ??
        Contact(
          id: '',
          archiveUserId: focusUserId,
          address: address.trim().toLowerCase(),
          createdAt: DateTime.now(),
        );
  }

  Future<void> removeByAddress(String address) {
    return _machine.send(RemoveContactByAddress(address));
  }

  void _syncLoadingFromMachine() {
    state.isLoading = _machine.loadState == ContactsLoadState.loading;
  }

  void _notify() => _onStateChanged();
}

class _LiveContactsEffects implements ContactsEffects {
  _LiveContactsEffects(this._coordinator);

  final ContactsCoordinator _coordinator;

  ContactsCoordinator get _c => _coordinator;

  @override
  Future<void> loadContacts() async {
    try {
      _c.state.contacts =
          await _c.contactService.fetchContacts(_c.focusUserId);
      _c.state.error = null;
      await _c._machine.send(const ContactsLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const ContactsLoadFailed());
    } finally {
      _c.syncLoadingFromMachine();
      _c.notifyStateChanged();
    }
  }

  @override
  Future<void> addByAddress(String address) async {
    await _c.contactService.addContact(
      archiveUserId: _c.focusUserId,
      address: address,
    );
  }

  @override
  Future<void> removeByAddress(String address) async {
    final contact = _c.contactForAddress(address);
    if (contact == null) return;
    await _c.contactService.deleteContact(contact.id);
  }
}
