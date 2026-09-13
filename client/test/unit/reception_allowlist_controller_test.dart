// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_reception_allowlist_service.dart';

void main() {
  late FakeReceptionAllowlistService service;
  late ReceptionAllowlistController controller;

  const focusUserId = 'focus-1';
  final alice = ProfileSummary(
    id: 'alice-id',
    username: 'alice', address: 'alice',
    displayName: 'Alice',
  );
  final bob = ProfileSummary(
    id: 'bob-id',
    username: 'bob', address: 'bob',
    displayName: 'Bob',
  );

  setUp(() {
    service = FakeReceptionAllowlistService();
    controller = ReceptionAllowlistController(
      focusUserId: focusUserId,
      allowlistService: service,
    );
  });

  test('load populates allowed people', () async {
    service.people = [AllowedPerson(entryId: 'entry-1', allowedAddress: alice.resolvedPeerAddress, profile: alice)];

    await controller.load();

    expect(controller.allowedPeople, hasLength(1));
    expect(controller.allowedAddresses, {'alice'});
    expect(controller.isLoading, isFalse);
  });

  test('addProfile skips self and duplicates', () async {
    await controller.load();

    await controller.addProfile(
      ProfileSummary(
        id: focusUserId,
        username: 'me',
        address: 'me',
        displayName: 'Me',
      ),
    );
    expect(service.addedAddresses, isEmpty);

    service.people = [AllowedPerson(entryId: 'e1', allowedAddress: alice.resolvedPeerAddress, profile: alice)];
    await controller.load();

    await controller.addProfile(alice);
    expect(service.addedAddresses, isEmpty);
  });

  test('addProfile calls service and reloads', () async {
    await controller.load();

    await controller.addProfile(bob);

    expect(service.addedAddresses.single, 'bob');
    expect(controller.allowedPeople.single.allowedAddress, 'bob');
  });

  test('load sorts allowed people by display name', () async {
    service.people = [
      AllowedPerson(
        entryId: 'e1',
        allowedAddress: 'zara',
        profile: ProfileSummary(
          id: 'z-id',
          username: 'zara',
          address: 'zara',
          displayName: 'Zara',
        ),
      ),
      AllowedPerson(
        entryId: 'e2',
        allowedAddress: 'anna',
        profile: ProfileSummary(
          id: 'a-id',
          username: 'anna',
          address: 'anna',
          displayName: 'Anna',
        ),
      ),
    ];

    await controller.load();

    expect(
      controller.allowedPeople.map((p) => p.displayName).toList(),
      ['Anna', 'Zara'],
    );
  });

  test('filteredAllowedPeople respects search query', () async {
    service.people = [
      AllowedPerson(entryId: 'e1', allowedAddress: alice.resolvedPeerAddress, profile: alice),
      AllowedPerson(entryId: 'e2', allowedAddress: bob.resolvedPeerAddress, profile: bob),
    ];
    await controller.load();

    controller.setSearchQuery('ali');
    expect(controller.filteredAllowedPeople, hasLength(1));
    expect(controller.filteredAllowedPeople.single.profile?.id, alice.id);
  });

  test('removeByAddress removes matching entry', () async {
    service.people = [AllowedPerson(entryId: 'e1', allowedAddress: alice.resolvedPeerAddress, profile: alice)];
    await controller.load();

    await controller.removeByAddress('alice');

    expect(controller.allowedPeople, isEmpty);
    expect(service.people, isEmpty);
  });
}
