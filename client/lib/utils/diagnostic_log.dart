// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'diagnostic/diagnostic_hub.dart';

export 'diagnostic/diagnostic_event.dart';
export 'diagnostic/diagnostic_flows.dart';
export 'diagnostic/diagnostic_hub.dart';
export 'diagnostic/diagnostic_sink.dart';

/// Log diagnostici client (solo sviluppo / agenti).
///
/// **Attivazione:** `--dart-define=ALFRED_DIAGNOSTIC_LOG=true` su `flutter run` o build
/// locale. GitHub Pages / `verify.sh --build` **non** passano il define → nessun output
/// (ramo eliminato a compile-time per la console; test usano [DiagnosticHub.installMemoryCapture]).
///
/// **API legacy:** [diagLog] / [diagLogFail] — preferire [DiagnosticHub.emit] e
/// [DiagnosticHub.beginTrace] sui confini macchina.
///
/// **Formato console:** `[alfred][flow] phase …` oppure `… FAIL motivo key=value`
///
/// **Flussi:** vedi [DiagnosticFlows]. **Lettura:** DevTools pagina, filtro `[alfred]`.
/// Vedi `AGENTS.md` § Log diagnostici e `client/scripts/test/README.md`.
const bool kDiagnosticLogEnabled = bool.fromEnvironment('ALFRED_DIAGNOSTIC_LOG');

void diagLog(
  String flow,
  String phase, {
  Map<String, Object?>? data,
}) {
  DiagnosticHub.instance.emit(flow, phase, data: data);
}

void diagLogFail(
  String flow,
  String phase,
  String reason, {
  Map<String, Object?>? data,
}) {
  DiagnosticHub.instance.emitFail(flow, phase, reason, data: data);
}
