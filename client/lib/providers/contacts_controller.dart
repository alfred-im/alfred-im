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
    required this.focusUserId,
    this.sessionEpoch = 0,
    required ContactService contactService,
  }) {
    _coordinator = ContactsCoordinator(
      focusUserId: focusUserId,
      contactService: contactService,
      onStateChanged: notifyListeners,
    );
  }

  final String focusUserId;

  /// Allineato a [AccountSession.epoch] — invalida il controller su restore sessione.
  final int sessionEpoch;

  late final ContactsCoordinator _coordinator;
  Future<void>? _loadFuture;

  List<Contact> get contacts => _coordinator.state.contacts;

  bool get isLoading => _coordinator.state.isLoading;

  String? get error => _coordinator.state.error;

  List<Contact> get filteredContacts => _coordinator.filteredContacts;

  Contact? contactForAddress(String address) =>
      _coordinator.contactForAddress(address);

  void setSearchQuery(String value) => _coordinator.setSearchQuery(value);

  Future<void> load() => _coordinator.load();

  /// Carica rubrica on-demand (chat, overlay profilo, schermata rubrica).
  Future<void> ensureLoaded() => _loadFuture ??= load();

  Future<List<ProfileSummary>> searchProfiles(String query) =>
      _coordinator.searchProfiles(query);

  Future<Contact> addByAddress(String address) =>
      _coordinator.addByAddress(address);

  Future<void> removeByAddress(String address) =>
      _coordinator.removeByAddress(address);
}
