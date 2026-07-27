// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/utils/diagnostic_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(DiagnosticHub.instance.resetForTest);

  test('hub inactive senza define né harness', () {
    expect(kDiagnosticLogEnabled, isFalse);
    expect(DiagnosticHub.instance.isActive, isFalse);
    DiagnosticHub.instance.emit('push', 'phase');
    expect(DiagnosticHub.instance.memorySink, isNull);
  });

  test('memory capture registra eventi formattati', () {
    final sink = DiagnosticHub.instance.installMemoryCapture();
    DiagnosticHub.instance.emit(
      DiagnosticFlows.messaging,
      'session.check',
      data: {'ok': true},
    );
    DiagnosticHub.instance.emitFail(
      DiagnosticFlows.scope,
      'inactive',
      'scope_mismatch',
      data: {'ownerUserId': 'a'},
    );

    expect(sink.events, hasLength(2));
    expect(
      sink.formattedLines().first,
      '[alfred][messaging] session.check ok=true',
    );
    expect(
      sink.any(flow: DiagnosticFlows.scope, failureOnly: true),
      isTrue,
    );
  });

  test('trace correlato op e traceId', () {
    final sink = DiagnosticHub.instance.installMemoryCapture();
    final trace = DiagnosticHub.instance.beginTrace(
      DiagnosticFlows.messaging,
      op: DiagnosticOps.sendText,
      data: {'peerProfileId': 'peer-b'},
    );
    trace.step('session.check', data: {'ok': true});
    trace.end();

    expect(sink.events, hasLength(3));
    expect(sink.events.first.traceId, isNotNull);
    expect(sink.events.first.op, DiagnosticOps.sendText);
    expect(sink.events.last.phase, 'trace.done');
  });

  test('DiagnosticFlows catalogo flussi principali', () {
    expect(DiagnosticFlows.all, contains(DiagnosticFlows.messaging));
    expect(DiagnosticFlows.all, contains(DiagnosticFlows.auth));
    expect(
      DiagnosticFlows.phasesFor(DiagnosticFlows.messaging),
      contains('session.check'),
    );
  });

  test('diagLog legacy delega al hub', () {
    final sink = DiagnosticHub.instance.installMemoryCapture();
    diagLog('push', 'hook.install');
    diagLogFail('nav', 'focus', 'timeout');
    expect(sink.events, hasLength(2));
    expect(sink.events.last.isFailure, isTrue);
  });
}
