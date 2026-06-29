import 'package:flutter/foundation.dart' show kIsWeb;

/// URL di ritorno dopo conferma email o reset password (Supabase Auth).
class AuthRedirectUrl {
  const AuthRedirectUrl._();

  static const production =
      'https://alfred-im.github.io/XmppTest/';

  static const _envOverride = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Risolve l'URL da passare a [emailRedirectTo] / [redirectTo].
  ///
  /// Su web usa l'origine corrente (GitHub Pages o dev locale); altrove
  /// [AUTH_REDIRECT_URL] o il default di produzione.
  static String resolve() {
    if (kIsWeb) {
      final base = Uri.base;
      if (base.hasScheme && base.host.isNotEmpty) {
        final path = base.path.endsWith('/') ? base.path : '${base.path}/';
        return base.replace(path: path, query: '', fragment: '').toString();
      }
    }

    if (_envOverride.isNotEmpty) {
      return _withTrailingSlash(_envOverride);
    }

    return production;
  }

  static String _withTrailingSlash(String url) =>
      url.endsWith('/') ? url : '$url/';
}
