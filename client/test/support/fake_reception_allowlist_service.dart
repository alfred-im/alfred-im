// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/reception_allowlist_service.dart';

import 'fake_messaging_services.dart';

class FakeReceptionAllowlistService extends ReceptionAllowlistService {
  FakeReceptionAllowlistService() : super(createTestSupabaseClient());

  List<AllowedPerson> people = [];
  final List<ProfileSummary> added = [];

  @override
  Future<List<AllowedPerson>> fetchAllowedPeople(String ownerId) async {
    final copy = List<AllowedPerson>.of(people);
    copy.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    return copy;
  }

  @override
  Future<AllowedPerson> addAllowedProfile({
    required String ownerId,
    required ProfileSummary profile,
  }) async {
    added.add(profile);
    final entry = AllowedPerson(
      entryId: 'entry-${profile.id}',
      profile: profile,
    );
    people = [...people, entry];
    return entry;
  }

  @override
  Future<void> removeAllowedPerson(String entryId) async {
    people = people.where((p) => p.entryId != entryId).toList();
  }
}
