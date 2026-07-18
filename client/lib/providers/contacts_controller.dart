// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../coordinators/contacts_coordinator.dart';
import '../models/contact.dart';
import '../models/profile_summary.dart';
import '../services/contact_service.dart';

/// Facade UI rubrica — orchestrazione in [ContactsCoordinator].
class ContactsController extends ChangeNotifier {
  ContactsController({
    required this.ownerId,
    required ContactService contactService,
  }) {
    _coordinator = ContactsCoordinator(
      ownerId: ownerId,
      contactService: contactService,
      onStateChanged: notifyListeners,
    );
  }

  final String ownerId;
  late final ContactsCoordinator _coordinator;

  List<Contact> get contacts => _coordinator.state.contacts;

  bool get isLoading => _coordinator.state.isLoading;

  String? get error => _coordinator.state.error;

  List<Contact> get filteredContacts => _coordinator.filteredContacts;

  Contact? contactForProfileId(String profileId) =>
      _coordinator.contactForProfileId(profileId);

  void setSearchQuery(String value) => _coordinator.setSearchQuery(value);

  Future<void> load() => _coordinator.load();

  Future<List<ProfileSummary>> searchProfiles(String query) =>
      _coordinator.searchProfiles(query);

  Future<Contact> addInternal(ProfileSummary profile) =>
      _coordinator.addInternal(profile);

  Future<void> removeInternalByProfileId(String profileId) =>
      _coordinator.removeInternalByProfileId(profileId);

  Future<Contact> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  }) =>
      _coordinator.addExternal(
        protocol: protocol,
        address: address,
        displayName: displayName,
      );
}
