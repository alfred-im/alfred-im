// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_summary.dart';

/// Ricerca profili Alfred via RPC `search_profiles`.
class ProfileSearchService {
  ProfileSearchService(this._client);

  final SupabaseClient _client;

  Future<List<ProfileSummary>> searchProfiles(String query) async {
    if (query.trim().length < 2) return [];

    final rows = await _client.rpc(
      'search_profiles',
      params: {'p_query': query.trim(), 'p_limit': 20},
    );

    return (rows as List<dynamic>)
        .map((r) => ProfileSummary.fromProfilesRow(r as Map<String, dynamic>))
        .toList();
  }
}
