// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/instance_config_schema.dart';
import '../models/instance_settings.dart';
import '../models/instance_stats.dart';

/// Operazioni riservate agli account `profile_kind = owner`.
class OwnerService {
  OwnerService(this._client);

  final SupabaseClient _client;

  Future<void> assertSessionActive() async {
    await _client.rpc('assert_session_active');
  }

  Future<bool> isInstanceOwner() async {
    final result = await _client.rpc('is_instance_owner');
    return result == true;
  }

  Future<InstanceStats> fetchStats() async {
    final raw = await _client.rpc('get_instance_stats');
    if (raw is! Map<String, dynamic>) {
      throw StateError('Statistiche istanza non disponibili.');
    }
    return InstanceStats.fromJson(raw);
  }

  Future<InstanceSettings> loadInstanceSettings() async {
    final raw = await _client.rpc('get_instance_bootstrap');
    if (raw is Map<String, dynamic>) {
      return InstanceSettings.fromBootstrapJson(raw);
    }
    return InstanceSettings.fromBootstrapJson(const {});
  }

  Future<void> saveInstanceSettings(InstanceSettings settings) async {
    final displayName = settings.displayName.trim();
    final imServerId = settings.imServerId.trim();
    if (displayName.isEmpty || imServerId.isEmpty) {
      throw StateError('Nome visualizzato e ID server IM sono obbligatori.');
    }

    await _client.rpc(
      'upsert_instance_config',
      params: {
        'p_key': InstanceConfigSchema.displayNameKey,
        'p_value': displayName,
      },
    );
    await _client.rpc(
      'upsert_instance_config',
      params: {
        'p_key': InstanceConfigSchema.imServerIdKey,
        'p_value': imServerId,
      },
    );

    final branding = _nonEmptyMap({
      'logo_url': settings.branding.logoUrl,
      'theme_color': settings.branding.themeColor,
    });
    await _client.rpc(
      'upsert_instance_config',
      params: {
        'p_key': InstanceConfigSchema.brandingKey,
        'p_value': branding,
      },
    );

    final legal = _nonEmptyMap({
      'privacy_url': settings.legal.privacyUrl,
      'terms_url': settings.legal.termsUrl,
      'support_url': settings.legal.supportUrl,
    });
    await _client.rpc(
      'upsert_instance_config',
      params: {
        'p_key': InstanceConfigSchema.legalKey,
        'p_value': legal,
      },
    );
  }

  Map<String, String> _nonEmptyMap(Map<String, String?> values) {
    final out = <String, String>{};
    for (final entry in values.entries) {
      final trimmed = entry.value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        out[entry.key] = trimmed;
      }
    }
    return out;
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
