// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import 'profile_search_service.dart';
import 'profile_service.dart';

class ReceptionAllowlistService {
  ReceptionAllowlistService(this._client)
      : _profileSearch = ProfileSearchService(_client),
        _profileService = ProfileService(_client);

  final SupabaseClient _client;
  final ProfileSearchService _profileSearch;
  final ProfileService _profileService;

  String get _authArchiveUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const AuthException('Sessione non disponibile.');
    }
    return id;
  }

  Future<List<AllowedPerson>> fetchAllowedPeople(String archiveUserId) async {
    final rows = await _client
        .from('reception_allowlist')
        .select('id, allowed_address')
        .eq('archive_user_id', archiveUserId)
        .order('created_at');

    final addresses = rows
        .map((row) => (row['allowed_address'] as String).trim().toLowerCase())
        .toList();
    final profilesByAddress = <String, ProfileSummary>{};
    if (addresses.isNotEmpty) {
      final profiles = await _profileService.fetchSummariesByAddresses(addresses);
      for (final profile in profiles) {
        final key = profile.address;
        if (key != null) profilesByAddress[key] = profile;
      }
    }

    final people = rows.map((row) {
      final address =
          (row['allowed_address'] as String).trim().toLowerCase();
      return AllowedPerson(
        entryId: row['id'] as String,
        allowedAddress: address,
        profile: profilesByAddress[address],
      );
    }).toList();

    people.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    return people;
  }

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _profileSearch.searchProfiles(query);
  }

  Future<AllowedPerson> addAllowedAddress({
    required String archiveUserId,
    required String address,
  }) async {
    final normalized = address.trim().toLowerCase();
    final row = await _client
        .from('reception_allowlist')
        .insert({
          'archive_user_id': _authArchiveUserId,
          'allowed_address': normalized,
        })
        .select('id, allowed_address')
        .single();

    final allowedAddress =
        (row['allowed_address'] as String).trim().toLowerCase();
    final profiles =
        await _profileService.fetchSummariesByAddresses([allowedAddress]);

    return AllowedPerson(
      entryId: row['id'] as String,
      allowedAddress: allowedAddress,
      profile: profiles.isEmpty ? null : profiles.first,
    );
  }

  Future<void> removeAllowedPerson(String entryId) async {
    await _client.from('reception_allowlist').delete().eq('id', entryId);
  }
}
