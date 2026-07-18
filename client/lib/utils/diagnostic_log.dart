// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Log diagnostici client — attivi solo con `--dart-define=ALFRED_DIAGNOSTIC_LOG=true`.
///
/// Release / GitHub Pages: define assente → nessun output (ramo eliminato a compile-time).
const bool kDiagnosticLogEnabled = bool.fromEnvironment('ALFRED_DIAGNOSTIC_LOG');

const _prefix = '[alfred]';

void diagLog(
  String category,
  String phase, {
  Map<String, Object?>? data,
}) {
  if (!kDiagnosticLogEnabled) return;
  debugPrint(_formatLine(category, phase, data: data));
}

void diagLogFail(
  String category,
  String phase,
  String reason, {
  Map<String, Object?>? data,
}) {
  if (!kDiagnosticLogEnabled) return;
  debugPrint(_formatLine(category, phase, fail: reason, data: data));
}

String _formatLine(
  String category,
  String phase, {
  String? fail,
  Map<String, Object?>? data,
}) {
  final buffer = StringBuffer('$_prefix[$category] $phase');
  if (fail != null && fail.isNotEmpty) {
    buffer.write(' FAIL $fail');
  }
  if (data != null) {
    for (final entry in data.entries) {
      buffer.write(' ${entry.key}=${entry.value}');
    }
  }
  return buffer.toString();
}
