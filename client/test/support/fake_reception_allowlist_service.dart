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
  final List<String> addedAddresses = [];

  @override
  Future<List<AllowedPerson>> fetchAllowedPeople(String archiveUserId) async {
    final copy = List<AllowedPerson>.of(people);
    copy.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return copy;
  }

  @override
  Future<AllowedPerson> addAllowedAddress({
    required String archiveUserId,
    required String address,
  }) async {
    final normalized = address.trim().toLowerCase();
    addedAddresses.add(normalized);
    final entry = AllowedPerson(
      entryId: 'entry-$normalized',
      allowedAddress: normalized,
      profile: ProfileSummary.fromAddress(normalized),
    );
    people = [...people, entry];
    return entry;
  }

  @override
  Future<void> removeAllowedPerson(String entryId) async {
    people = people.where((p) => p.entryId != entryId).toList();
  }
}
