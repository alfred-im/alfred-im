// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/services/contact_service.dart';

import 'fake_messaging_services.dart';

class FakeContactService extends ContactService {
  FakeContactService() : super(createTestSupabaseClient());

  List<Contact> contacts = [];
  final List<String> deletedIds = [];

  @override
  Future<List<Contact>> fetchContacts(String archiveUserId) async =>
      List.of(contacts);

  @override
  Future<Contact> addContact({
    required String archiveUserId,
    required String address,
  }) async {
    final normalized = address.trim().toLowerCase();
    final contact = Contact(
      id: 'contact-$normalized',
      archiveUserId: archiveUserId,
      address: normalized,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    contacts = [...contacts, contact];
    return contact;
  }

  @override
  Future<void> deleteContact(String contactId) async {
    deletedIds.add(contactId);
    contacts = contacts.where((c) => c.id != contactId).toList();
  }
}
