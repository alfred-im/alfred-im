// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:web/web.dart' as web;

import 'diagnostic_log.dart';
import 'push_deep_link.dart';

String? _bootPushFragment;

String? _fragmentFromHash(String hash) {
  if (hash.isEmpty) return null;
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

/// Conserva `#push-chat/...` se Flutter azzera l'hash al bootstrap.
void captureBootPushLaunchFragment() {
  final fragment = _fragmentFromHash(web.window.location.hash);
  if (fragment != null && fragment.startsWith(PushDeepLink.fragmentPrefix)) {
    _bootPushFragment = fragment;
    diagLog('push', 'fragment.boot_capture', data: {'fragment': fragment});
  }
}

String? readPushLaunchFragment() {
  final live = _fragmentFromHash(web.window.location.hash);
  if (live != null && live.startsWith(PushDeepLink.fragmentPrefix)) {
    _bootPushFragment = live;
    return live;
  }
  return _bootPushFragment;
}

void clearPushLaunchFragment() {
  _bootPushFragment = null;
  final base = '${web.window.location.pathname}${web.window.location.search}';
  web.window.history.replaceState(null, '', base);
}
