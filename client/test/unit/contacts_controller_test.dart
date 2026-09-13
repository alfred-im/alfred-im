// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_contact_service.dart';

void main() {
  late FakeContactService service;
  late ContactsController controller;

  const focusUserId = 'focus-1';

  setUp(() {
    service = FakeContactService();
    controller = ContactsController(
      focusUserId: focusUserId,
      contactService: service,
    );
  });

  test('contactForAddress finds internal contact', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        address: 'alice',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    await controller.load();

    expect(controller.contactForAddress('alice')?.id, 'c1');
    expect(controller.contactForAddress('missing'), isNull);
  });

  test('ensureLoaded loads contacts once', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        address: 'alice',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    await controller.ensureLoaded();

    expect(controller.contactForAddress('alice')?.id, 'c1');
    await controller.ensureLoaded();
    expect(controller.contacts, hasLength(1));
  });

  test('removeByAddress deletes contact', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        address: 'alice',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    await controller.load();

    await controller.removeByAddress('alice');

    expect(service.deletedIds, ['c1']);
    expect(controller.contacts, isEmpty);
  });
}
