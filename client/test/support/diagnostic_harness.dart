// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/utils/diagnostic/diagnostic_hub.dart';
import 'package:alfred_client/utils/diagnostic/diagnostic_sink.dart';

/// Harness diagnostica per test agente — cattura eventi strutturati senza define.
class DiagnosticHarness {
  DiagnosticHarness() : _sink = DiagnosticHub.instance.installMemoryCapture();

  final MemoryDiagnosticSink _sink;

  List<String> get lines => _sink.formattedLines();

  bool any({
    String? flow,
    String? phaseContains,
    bool? failureOnly,
  }) {
    return _sink.any(
      flow: flow,
      phaseContains: phaseContains,
      failureOnly: failureOnly,
    );
  }

  void clear() => _sink.clear();

  void dispose() => DiagnosticHub.instance.resetForTest();
}
