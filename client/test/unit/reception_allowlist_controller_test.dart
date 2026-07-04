import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_reception_allowlist_service.dart';

void main() {
  late FakeReceptionAllowlistService service;
  late ReceptionAllowlistController controller;

  const ownerId = 'owner-1';
  final alice = ProfileSummary(
    id: 'alice-id',
    username: 'alice',
    displayName: 'Alice',
  );
  final bob = ProfileSummary(
    id: 'bob-id',
    username: 'bob',
    displayName: 'Bob',
  );

  setUp(() {
    service = FakeReceptionAllowlistService();
    controller = ReceptionAllowlistController(
      ownerId: ownerId,
      allowlistService: service,
    );
  });

  test('load populates allowed people', () async {
    service.people = [AllowedPerson(entryId: 'entry-1', profile: alice)];

    await controller.load();

    expect(controller.allowedPeople, hasLength(1));
    expect(controller.allowedProfileIds, {'alice-id'});
    expect(controller.isLoading, isFalse);
  });

  test('addProfile skips self and duplicates', () async {
    await controller.load();

    await controller.addProfile(
      ProfileSummary(id: ownerId, displayName: 'Me'),
    );
    expect(service.added, isEmpty);

    service.people = [AllowedPerson(entryId: 'e1', profile: alice)];
    await controller.load();

    await controller.addProfile(alice);
    expect(service.added, isEmpty);
  });

  test('addProfile calls service and reloads', () async {
    await controller.load();

    await controller.addProfile(bob);

    expect(service.added.single.id, bob.id);
    expect(controller.allowedPeople.single.profile.id, bob.id);
  });

  test('filteredAllowedPeople respects search query', () async {
    service.people = [
      AllowedPerson(entryId: 'e1', profile: alice),
      AllowedPerson(entryId: 'e2', profile: bob),
    ];
    await controller.load();

    controller.setSearchQuery('ali');
    expect(controller.filteredAllowedPeople, hasLength(1));
    expect(controller.filteredAllowedPeople.single.profile.id, alice.id);
  });
}
