// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import 'diagnostic_event.dart';

/// Destinazione eventi diagnostici (console, buffer test, composizione).
abstract class DiagnosticSink {
  void onEvent(DiagnosticEvent event);
}

/// Output DevTools / Playwright — una riga per evento.
class ConsoleDiagnosticSink implements DiagnosticSink {
  @override
  void onEvent(DiagnosticEvent event) {
    debugPrint(event.formatLine());
  }
}

/// Buffer in-memory per test e harness agente.
class MemoryDiagnosticSink implements DiagnosticSink {
  final List<DiagnosticEvent> events = <DiagnosticEvent>[];

  @override
  void onEvent(DiagnosticEvent event) {
    events.add(event);
  }

  void clear() => events.clear();

  List<String> formattedLines() =>
      events.map((event) => event.formatLine()).toList();

  bool any({
    String? flow,
    String? phaseContains,
    bool? failureOnly,
    bool Function(DiagnosticEvent event)? predicate,
  }) {
    return events.any((event) {
      if (!event.matches(
        expectedFlow: flow,
        phaseContains: phaseContains,
        failureOnly: failureOnly,
      )) {
        return false;
      }
      if (predicate != null && !predicate(event)) return false;
      return true;
    });
  }
}

/// Compositore: tutti i sink registrati ricevono ogni evento.
class CompositeDiagnosticSink implements DiagnosticSink {
  CompositeDiagnosticSink(this._sinks);

  final List<DiagnosticSink> _sinks;

  void add(DiagnosticSink sink) => _sinks.add(sink);

  @override
  void onEvent(DiagnosticEvent event) {
    for (final sink in _sinks) {
      sink.onEvent(event);
    }
  }
}
