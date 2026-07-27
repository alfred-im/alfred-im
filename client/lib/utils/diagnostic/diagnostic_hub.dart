// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import 'diagnostic_event.dart';
import 'diagnostic_sink.dart';

/// Hub centrale diagnostica — unico ingresso per flussi osservabili.
class DiagnosticHub {
  DiagnosticHub._();

  static final DiagnosticHub instance = DiagnosticHub._();

  static const _compileTimeEnabled = bool.fromEnvironment('ALFRED_DIAGNOSTIC_LOG');

  final ConsoleDiagnosticSink _console = ConsoleDiagnosticSink();
  MemoryDiagnosticSink? _memory;
  bool _testForceEnabled = false;
  int _traceCounter = 0;

  bool get isActive => _compileTimeEnabled || _testForceEnabled;

  MemoryDiagnosticSink? get memorySink => _memory;

  /// Abilita cattura in test senza `--dart-define=ALFRED_DIAGNOSTIC_LOG`.
  @visibleForTesting
  MemoryDiagnosticSink installMemoryCapture() {
    _testForceEnabled = true;
    _memory ??= MemoryDiagnosticSink();
    _memory!.clear();
    return _memory!;
  }

  @visibleForTesting
  void resetForTest() {
    _testForceEnabled = false;
    _memory?.clear();
    _memory = null;
    _traceCounter = 0;
  }

  void emit(
    String flow,
    String phase, {
    Map<String, Object?>? data,
    String? traceId,
    String? op,
  }) {
    _emit(
      flow: flow,
      phase: phase,
      data: data,
      traceId: traceId,
      op: op,
    );
  }

  void emitFail(
    String flow,
    String phase,
    String reason, {
    Map<String, Object?>? data,
    String? traceId,
    String? op,
  }) {
    _emit(
      flow: flow,
      phase: phase,
      fail: reason,
      data: data,
      traceId: traceId,
      op: op,
    );
  }

  DiagnosticTrace beginTrace(
    String flow, {
    String? op,
    Map<String, Object?>? data,
  }) {
    final traceId = '$flow-${++_traceCounter}';
    final trace = DiagnosticTrace._(
      this,
      flow: flow,
      traceId: traceId,
      op: op,
    );
    trace.step('trace.start', data: data);
    return trace;
  }

  /// Usato da [DiagnosticTrace] — non chiamare direttamente dal prodotto.
  void record({
    required String flow,
    required String phase,
    String? fail,
    Map<String, Object?>? data,
    String? traceId,
    String? op,
  }) {
    _emit(
      flow: flow,
      phase: phase,
      fail: fail,
      data: data,
      traceId: traceId,
      op: op,
    );
  }

  void _emit({
    required String flow,
    required String phase,
    String? fail,
    Map<String, Object?>? data,
    String? traceId,
    String? op,
  }) {
    if (!isActive) return;
    final event = DiagnosticEvent(
      flow: flow,
      phase: phase,
      fail: fail,
      data: data,
      traceId: traceId,
      op: op,
      timestamp: DateTime.now(),
    );
    _console.onEvent(event);
    _memory?.onEvent(event);
  }
}

/// Traccia correlata multi-step (es. load conversazione, invio outbound).
class DiagnosticTrace {
  DiagnosticTrace._(
    this._hub, {
    required this.flow,
    required this.traceId,
    this.op,
  }) : _open = true;

  final DiagnosticHub _hub;
  final String flow;
  final String traceId;
  final String? op;
  bool _open;

  void step(String phase, {Map<String, Object?>? data}) {
    if (!_open) return;
    _hub.record(
      flow: flow,
      phase: phase,
      traceId: traceId,
      op: op,
      data: data,
    );
  }

  void fail(String phase, String reason, {Map<String, Object?>? data}) {
    if (!_open) return;
    _hub.record(
      flow: flow,
      phase: phase,
      fail: reason,
      traceId: traceId,
      op: op,
      data: data,
    );
    _open = false;
  }

  void end({bool ok = true, String phase = 'trace.done', Map<String, Object?>? data}) {
    if (!_open) return;
    if (!ok) {
      fail(phase, 'aborted', data: data);
      return;
    }
    step(phase, data: data);
    _open = false;
  }
}
