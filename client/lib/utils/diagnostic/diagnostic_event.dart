// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Evento diagnostico strutturato — unità di osservabilità nei test e in dev.
class DiagnosticEvent {
  const DiagnosticEvent({
    required this.flow,
    required this.phase,
    this.fail,
    this.data,
    this.traceId,
    this.op,
    required this.timestamp,
  });

  final String flow;
  final String phase;
  final String? fail;
  final Map<String, Object?>? data;
  final String? traceId;
  final String? op;
  final DateTime timestamp;

  bool get isFailure => fail != null && fail!.isNotEmpty;

  /// Formato console stabile per e2e (`[alfred][flow] …`) e filtri agente.
  String formatLine({String prefix = '[alfred]'}) {
    final buffer = StringBuffer('$prefix[$flow] $phase');
    if (isFailure) {
      buffer.write(' FAIL $fail');
    }
    if (traceId != null && traceId!.isNotEmpty) {
      buffer.write(' trace=$traceId');
    }
    if (op != null && op!.isNotEmpty) {
      buffer.write(' op=$op');
    }
    final payload = data;
    if (payload != null) {
      for (final entry in payload.entries) {
        buffer.write(' ${entry.key}=${entry.value}');
      }
    }
    return buffer.toString();
  }

  /// Filtro per flow + phase (es. `messaging`, `session.check`).
  bool matches({String? expectedFlow, String? phaseContains, bool? failureOnly}) {
    if (expectedFlow != null && flow != expectedFlow) return false;
    if (phaseContains != null && !phase.contains(phaseContains)) {
      return false;
    }
    if (failureOnly == true && !isFailure) return false;
    if (failureOnly == false && isFailure) return false;
    return true;
  }
}
