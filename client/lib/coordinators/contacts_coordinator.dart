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

  Future<Contact> addInternal(ProfileSummary profile) async {
    await _machine.send(AddInternalContact(profile));
    return contactForProfileId(profile.id) ??
        Contact(
          id: '',
          archiveUserId: focusUserId,
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
    final trimmedAddress = address.trim();
    for (final contact in state.contacts) {
      if (contact.protocol == protocol &&
          contact.externalAddress == trimmedAddress) {
        return contact;
      }
    }
    return state.contacts.last;
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
  Future<void> addInternal(ProfileSummary profile) async {
    await _c.contactService.addInternalContact(
      archiveUserId: _c.focusUserId,
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
      archiveUserId: _c.focusUserId,
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
