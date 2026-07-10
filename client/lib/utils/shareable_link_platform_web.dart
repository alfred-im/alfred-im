// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

/// Fragment letto al primo frame — conservato se il bootstrap Flutter azzera l'hash.
String? _bootFragment;

String? _fragmentFromHash(String hash) {
  if (hash.isEmpty) return null;
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

/// Chiamare subito dopo [WidgetsFlutterBinding.ensureInitialized].
void captureBootShareableFragment() {
  final fragment = _fragmentFromHash(html.window.location.hash);
  if (fragment != null) {
    _bootFragment = fragment;
  }
}

String? readShareableFragment() {
  final live = _fragmentFromHash(html.window.location.hash);
  if (live != null) {
    _bootFragment = live;
    return live;
  }
  return _bootFragment;
}

void clearShareableFragment() {
  _bootFragment = null;
  final base = '${html.window.location.pathname}${html.window.location.search}';
  html.window.history.replaceState(null, '', base);
}

Stream<String?> watchShareableFragment() {
  return html.window.onHashChange.map((_) {
    final hash = html.window.location.hash;
    if (hash.isEmpty) {
      _bootFragment = null;
      return null;
    }
    return readShareableFragment();
  });
}
