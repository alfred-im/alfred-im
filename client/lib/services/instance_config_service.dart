// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/instance_settings.dart';
import '../runtime/instance_runtime.dart';

/// Legge configurazione istanza dal backend (RPC — mai tabella diretta).
class InstanceConfigService {
  InstanceConfigService(this._client);

  final SupabaseClient _client;

  Future<InstanceSettings> fetchSettings() async {
    final raw = await _client.rpc('get_instance_bootstrap');
    if (raw is! Map) {
      return InstanceSettings.fromBootstrapJson(const {});
    }
    return InstanceSettings.fromBootstrapJson(
      Map<String, dynamic>.from(raw),
    );
  }

  Future<String> fetchVapidPublicKey() async {
    final raw = await _client.rpc('get_push_vapid_public_key');
    if (raw is! String) return '';
    return raw.trim();
  }

  Future<InstanceRuntime> loadRuntime() async {
    final settings = await fetchSettings();
    final vapid = await fetchVapidPublicKey();
    final runtime = InstanceRuntime(settings: settings, vapidPublicKey: vapid);
    InstanceRuntime.install(runtime);
    return runtime;
  }
}
