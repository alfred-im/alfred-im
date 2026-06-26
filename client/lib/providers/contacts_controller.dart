import 'package:flutter/foundation.dart';

import '../models/contact.dart';
import '../services/contact_service.dart';
import '../utils/list_filter.dart';

class ContactsController extends ChangeNotifier {
  ContactsController({
    required this.ownerId,
    ContactService? contactService,
  }) : _contactService = contactService ?? ContactService() {
    load();
  }

  final String ownerId;
  final ContactService _contactService;

  List<Contact> contacts = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  List<Contact> get filteredContacts => filterByQuery(
        contacts,
        _searchQuery,
        (contact) => contact.displayName,
      );

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      contacts = await _contactService.fetchContacts(ownerId);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ProfileSearchResult>> searchProfiles(String query) {
    return _contactService.searchProfiles(query);
  }

  Future<Contact> addInternal(ProfileSearchResult profile) async {
    final contact = await _contactService.addInternalContact(
      ownerId: ownerId,
      profile: profile,
    );
    await load();
    return contact;
  }

  Future<Contact> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  }) async {
    final contact = await _contactService.addExternalContact(
      ownerId: ownerId,
      protocol: protocol,
      externalAddress: address,
      displayName: displayName,
    );
    await load();
    return contact;
  }
}
