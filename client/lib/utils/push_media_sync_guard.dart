// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Blocca sync push durante picker media / upload (PROM-PUSH-NOTIFY-047).
class PushMediaSyncGuard {
  static int _depth = 0;

  static bool get isActive => _depth > 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
    }
  }
}
