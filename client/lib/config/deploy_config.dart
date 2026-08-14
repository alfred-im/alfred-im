// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Deploy-time wiring for this instance (written at deploy — see `config.json.example`).
class DeployConfig {
  DeployConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.publicBaseUrl,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? publicBaseUrl;

  static DeployConfig? _loaded;

  static DeployConfig get require {
    final config = _loaded;
    if (config == null) {
      throw StateError('DeployConfig non caricato — chiamare load() prima.');
    }
    return config;
  }

  static bool get isLoaded => _loaded != null;

  @visibleForTesting
  static void overrideForTest(DeployConfig config) {
    _loaded = config;
  }

  @visibleForTesting
  static void resetForTest() {
    _loaded = null;
  }

  static Future<DeployConfig> load() async {
    if (kIsWeb) {
      return _loadFromWeb();
    }
    return _loadFromEnvironment();
  }

  static Future<DeployConfig> _loadFromWeb() async {
    final uri = Uri.base.resolve('config.json');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw DeployConfigException(
        'config.json non trovato (${response.statusCode}) all''origine ${Uri.base.origin}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw DeployConfigException('config.json deve essere un oggetto JSON.');
    }
    final config = _parseMap(decoded);
    _loaded = config;
    return config;
  }

  static DeployConfig _loadFromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
    const publicBase = String.fromEnvironment('PUBLIC_BASE_URL');
    if (url.isEmpty || anon.isEmpty) {
      throw DeployConfigException(
        'SUPABASE_URL e SUPABASE_ANON_KEY obbligatori (--dart-define) fuori web.',
      );
    }
    final config = DeployConfig(
      supabaseUrl: url,
      supabaseAnonKey: anon,
      publicBaseUrl: publicBase.isEmpty ? null : publicBase,
    );
    _loaded = config;
    return config;
  }

  static DeployConfig _parseMap(Map<String, dynamic> map) {
    final url = map['supabaseUrl'];
    final anon = map['supabaseAnonKey'];
    if (url is! String || url.trim().isEmpty) {
      throw DeployConfigException('config.json: supabaseUrl obbligatorio.');
    }
    if (anon is! String || anon.trim().isEmpty) {
      throw DeployConfigException('config.json: supabaseAnonKey obbligatorio.');
    }
    final publicBase = map['publicBaseUrl'];
    return DeployConfig(
      supabaseUrl: url.trim(),
      supabaseAnonKey: anon.trim(),
      publicBaseUrl: publicBase is String && publicBase.trim().isNotEmpty
          ? _withTrailingSlash(publicBase.trim())
          : null,
    );
  }

  static String _withTrailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';
}

class DeployConfigException implements Exception {
  DeployConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}
