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
  bool isLoading = true;
  String? error;
}

/// Orchestrazione load, filtro e CRUD rubrica.
class ContactsCoordinator {
  ContactsCoordinator({
    required this.ownerId,
    required this._contactService,
    required this._onStateChanged,
  }) {
    _machine = ContactsMachine(_LiveContactsEffects._(this));
    unawaited(load());
  }

  final String ownerId;
  final ContactService _contactService;
  final void Function() _onStateChanged;
  late final ContactsMachine _machine;
  final ContactsState state = ContactsState();

  ContactsMachine get machine => _machine;

  List<Contact> get filteredContacts => filterByQuery(
        state.contacts,
        _machine.searchQuery,
        (contact) => contact.displayName,
      );

  Contact? contactForProfileId(String profileId) {
    for (final contact in state.contacts) {
      if (contact.protocol == ContactProtocol.internal &&
          contact.linkedProfileId == profileId) {
        return contact;
      }
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

  Contact? _lastAddedContact;

  Future<Contact> addInternal(ProfileSummary profile) async {
    await _machine.send(AddInternalContact(profile));
    return _lastAddedContact ??
        contactForProfileId(profile.id) ??
        Contact(
          id: '',
          ownerId: ownerId,
          protocol: ContactProtocol.internal,
          linkedProfileId: profile.id,
          displayName: profile.displayName,
          createdAt: DateTime.now(),
        );
  }

  Future<void> removeInternalByProfileId(String profileId) {
    return _machine.send(RemoveInternalContact(profileId));
  }

  Future<Contact> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  }) async {
    await _machine.send(
      AddExternalContact(
        protocol: protocol,
        address: address,
        displayName: displayName,
      ),
    );
    return _lastAddedContact ?? state.contacts.last;
  }

  void _syncLoadingFromMachine() {
    state.isLoading = _machine.loadState == ContactsLoadState.loading;
  }

  void _notify() => _onStateChanged();
}

class _LiveContactsEffects implements ContactsEffects {
  _LiveContactsEffects._(this._coordinator);

  final ContactsCoordinator _coordinator;

  ContactsCoordinator get _c => _coordinator;

  @override
  Future<void> loadContacts() async {
    try {
      _c.state.contacts = await _c._contactService.fetchContacts(_c.ownerId);
      _c.state.error = null;
      await _c._machine.send(const ContactsLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const ContactsLoadFailed());
    } finally {
      _c._syncLoadingFromMachine();
      _c._notify();
    }
  }

  @override
  void onSearchQueryChanged(String query) {
    // Query vive sulla macchina; la UI legge filteredContacts.
  }

  @override
  Future<void> addInternal(ProfileSummary profile) async {
    _c._lastAddedContact = await _c._contactService.addInternalContact(
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
    _c._lastAddedContact = await _c._contactService.addExternalContact(
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
    await _c._contactService.deleteContact(contact.id);
  }
}
