import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// URL di ritorno dopo conferma email o reset password (Supabase Auth).
class AuthRedirectUrl {
  const AuthRedirectUrl._();

  /// URL demo di sviluppo su GitHub Pages — **non** produzione.
  static const devDemoDefault = 'https://alfred-im.github.io/XmppTest/';

  /// Alias storico; preferire [devDemoDefault].
  @Deprecated('GitHub Pages è demo di sviluppo, non produzione — usare devDemoDefault')
  static const production = devDemoDefault;

  static const _envOverride = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Risolve l'URL da passare a [emailRedirectTo] / [redirectTo].
  ///
  /// Su web: istanza pubblica → [devDemoDefault]; solo `localhost` / `127.0.0.1`
  /// usano l'origine corrente (dev agente). Fuori web: [AUTH_REDIRECT_URL] o
  /// [devDemoDefault].
  static String resolve() {
    if (kIsWeb) {
      return resolveForOrigin(Uri.base);
    }

    if (_envOverride.isNotEmpty) {
      return _withTrailingSlash(_envOverride);
    }

    return devDemoDefault;
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

    return devDemoDefault;
  }

  static bool _isLocalDevHost(String host) =>
      host == 'localhost' || host == '127.0.0.1';

  static String _withTrailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';
}
