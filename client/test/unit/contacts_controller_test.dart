// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_contact_service.dart';

void main() {
  late FakeContactService service;
  late ContactsController controller;

  const focusUserId = 'focus-1';
  final alice = ProfileSummary(
    id: 'alice-id',
    username: 'alice',
    displayName: 'Alice',
  );

  setUp(() {
    service = FakeContactService();
    controller = ContactsController(
      focusUserId: focusUserId,
      contactService: service,
    );
  });

  test('contactForProfileId finds internal contact', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        protocol: ContactProtocol.internal,
        linkedProfileId: alice.id,
        displayName: alice.displayName,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    await controller.load();

    expect(controller.contactForProfileId(alice.id)?.id, 'c1');
    expect(controller.contactForProfileId('missing'), isNull);
  });

  test('ensureLoaded loads contacts once', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        protocol: ContactProtocol.internal,
        linkedProfileId: alice.id,
        displayName: alice.displayName,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];

    await controller.ensureLoaded();

    expect(controller.contactForProfileId(alice.id)?.id, 'c1');
    await controller.ensureLoaded();
    expect(controller.contacts, hasLength(1));
  });

  test('removeInternalByProfileId deletes contact', () async {
    service.contacts = [
      Contact(
        id: 'c1',
        archiveUserId: focusUserId,
        protocol: ContactProtocol.internal,
        linkedProfileId: alice.id,
        displayName: alice.displayName,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ];
    await controller.load();

    await controller.removeInternalByProfileId(alice.id);

    expect(service.deletedIds, ['c1']);
    expect(controller.contacts, isEmpty);
  });
}
