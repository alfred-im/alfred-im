// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/providers/contacts_controller.dart';

import '../support/fake_contact_service.dart';

void main() {
  group('contacts wiring', () {
    const focusUserId = 'focus-1';
    const aliceAddress = 'alice';

    test('load attraversa coordinator ed effects live', () async {
      final service = FakeContactService()
        ..contacts = [
          Contact(
            id: 'c1',
            archiveUserId: focusUserId,
            address: aliceAddress,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ];
      final controller = ContactsController(
        focusUserId: focusUserId,
        contactService: service,
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.contacts, hasLength(1));
      expect(controller.contactForAddress(aliceAddress)?.id, 'c1');
    });

    test('addByAddress attraversa macchina e service', () async {
      final service = FakeContactService();
      final controller = ContactsController(
        focusUserId: focusUserId,
        contactService: service,
      );

      await controller.load();

      final contact = await controller.addByAddress(aliceAddress);

      expect(contact.address, aliceAddress);
      expect(service.contacts, hasLength(1));
      expect(controller.contacts.first.address, aliceAddress);
    });
  });
}
