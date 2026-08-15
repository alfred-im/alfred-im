// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '../config/deploy_config.dart';

/// URL di ritorno dopo conferma email o reset password (Supabase Auth).
class AuthRedirectUrl {
  const AuthRedirectUrl._();

  static const _envOverride = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Risolve l'URL da passare a [emailRedirectTo] / [redirectTo].
  static String resolve() {
    if (kIsWeb) {
      return resolveForOrigin(Uri.base);
    }

    if (_envOverride.isNotEmpty) {
      return _withTrailingSlash(_envOverride);
    }

    final fromDeploy = DeployConfig.isLoaded
        ? DeployConfig.require.publicBaseUrl
        : null;
    if (fromDeploy != null && fromDeploy.isNotEmpty) {
      return fromDeploy;
    }

    throw StateError(
      'publicBaseUrl non configurato: imposta config.json o AUTH_REDIRECT_URL.',
    );
  }

  @visibleForTesting
  static String resolveForOrigin(Uri base) {
    if (base.hasScheme && base.host.isNotEmpty && _isLocalDevHost(base.host)) {
      final path = base.path.endsWith('/') ? base.path : '${base.path}/';
      return Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: path,
      ).toString();
    }

    final fromDeploy = DeployConfig.isLoaded
        ? DeployConfig.require.publicBaseUrl
        : null;
    if (fromDeploy != null && fromDeploy.isNotEmpty) {
      return fromDeploy;
    }

    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    ).toString();
  }

  static bool _isLocalDevHost(String host) =>
      host == 'localhost' || host == '127.0.0.1';

  static String _withTrailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';
}
