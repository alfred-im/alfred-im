// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../models/profile_summary.dart';
import 'profile_search_service.dart';

class ContactService {
  ContactService(this._client) : _profileSearch = ProfileSearchService(_client);

  final SupabaseClient _client;
  final ProfileSearchService _profileSearch;

  String get _authArchiveUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const AuthException('Sessione non disponibile.');
    }
    return id;
  }

  Future<List<Contact>> fetchContacts(String archiveUserId) async {
    final rows = await _client
        .from('contacts')
        .select()
        .eq('archive_user_id', archiveUserId)
        .order('display_name');

    return rows.map((r) => Contact.fromJson(r)).toList();
  }

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _profileSearch.searchProfiles(query);
  }

  Future<Contact> addInternalContact({
    required String archiveUserId,
    required ProfileSummary profile,
  }) async {
    final row = await _client
        .from('contacts')
        .insert({
          'archive_user_id': _authArchiveUserId,
          'protocol': 'internal',
          'linked_profile_id': profile.id,
          'display_name': profile.displayName,
          'avatar_url': ?profile.avatarUrl,
        })
        .select()
        .single();

    return Contact.fromJson(row);
  }

  Future<Contact> addExternalContact({
    required String archiveUserId,
    required ContactProtocol protocol,
    required String externalAddress,
    required String displayName,
  }) async {
    final row = await _client
        .from('contacts')
        .insert({
          'archive_user_id': _authArchiveUserId,
          'protocol': protocol.name,
          'external_address': externalAddress,
          'display_name': displayName,
        })
        .select()
        .single();

    return Contact.fromJson(row);
  }

  Future<void> deleteContact(String contactId) async {
    await _client.from('contacts').delete().eq('id', contactId);
  }
}
