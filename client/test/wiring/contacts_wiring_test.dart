// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/contacts_controller.dart';

import '../support/fake_contact_service.dart';

/// Wiring: ContactsController → ContactsCoordinator → LiveContactsEffects.
void main() {
  group('contacts wiring', () {
    const focusUserId = 'focus-1';
    final alice = ProfileSummary(
      id: 'alice-id',
      username: 'alice',
      displayName: 'Alice',
    );

    test('load attraversa coordinator ed effects live', () async {
      final service = FakeContactService()
        ..contacts = [
          Contact(
            id: 'c1',
            archiveUserId: focusUserId,
            protocol: ContactProtocol.internal,
            linkedProfileId: alice.id,
            displayName: alice.displayName,
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
      expect(controller.contactForProfileId(alice.id)?.id, 'c1');
    });

    test('addInternal attraversa macchina e service', () async {
      final service = FakeContactService();
      final controller = ContactsController(
        focusUserId: focusUserId,
        contactService: service,
      );

      await controller.load();

      final contact = await controller.addInternal(alice);

      expect(contact.linkedProfileId, alice.id);
      expect(service.contacts, hasLength(1));
      expect(
        controller.contacts.first.protocol,
        ContactProtocol.internal,
      );
    });
  });
}
