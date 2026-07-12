// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// URL di ritorno dopo conferma email o reset password (Supabase Auth).
class AuthRedirectUrl {
  const AuthRedirectUrl._();

  /// Web client pubblicato su GitHub Pages (`alfred-im` repository).
  static const githubPagesDefault = 'https://alfred-im.github.io/alfred-im/';

  /// Alias storico pre-rinomina repository/path Pages.
  @Deprecated('Use githubPagesDefault')
  static const devDemoDefault = githubPagesDefault;

  /// Alias storico; preferire [githubPagesDefault].
  @Deprecated('Use githubPagesDefault')
  static const production = githubPagesDefault;

  static const _envOverride = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Risolve l'URL da passare a [emailRedirectTo] / [redirectTo].
  ///
  /// Su web: istanza pubblica → [githubPagesDefault]; solo `localhost` / `127.0.0.1`
  /// usano l'origine corrente (dev agente). Fuori web: [AUTH_REDIRECT_URL] o
  /// [githubPagesDefault].
  static String resolve() {
    if (kIsWeb) {
      return resolveForOrigin(Uri.base);
    }

    if (_envOverride.isNotEmpty) {
      return _withTrailingSlash(_envOverride);
    }

    return githubPagesDefault;
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

    return githubPagesDefault;
  }

  static bool _isLocalDevHost(String host) =>
      host == 'localhost' || host == '127.0.0.1';

  static String _withTrailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';
}
