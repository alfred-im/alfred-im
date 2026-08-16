// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/instance_config_entry.dart';
import '../models/instance_stats.dart';

/// Operazioni riservate agli account `profile_kind = owner`.
class OwnerService {
  OwnerService(this._client);

  final SupabaseClient _client;

  Future<void> assertSessionActive() async {
    await _client.rpc('assert_session_active');
  }

  Future<InstanceStats> fetchStats() async {
    final raw = await _client.rpc('get_instance_stats');
    if (raw is! Map<String, dynamic>) {
      throw StateError('Statistiche istanza non disponibili.');
    }
    return InstanceStats.fromJson(raw);
  }

  Future<List<InstanceConfigEntry>> listConfig() async {
    final rows = await _client.rpc('list_instance_config');
    if (rows is! List) return const [];
    return rows
        .map((row) => InstanceConfigEntry.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertConfig({
    required String key,
    required dynamic value,
  }) async {
    await _client.rpc(
      'upsert_instance_config',
      params: {
        'p_key': key,
        'p_value': value,
      },
    );
  }

  Future<void> banProfile(String profileId) async {
    await _client.rpc('ban_profile', params: {'p_target_profile_id': profileId});
  }

  Future<void> unbanProfile(String profileId) async {
    await _client.rpc(
      'unban_profile',
      params: {'p_target_profile_id': profileId},
    );
  }
}
