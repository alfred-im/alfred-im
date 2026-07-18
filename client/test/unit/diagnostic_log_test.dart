// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/utils/diagnostic_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagLog e diagLogFail non lanciano senza define', () {
    expect(kDiagnosticLogEnabled, isFalse);
    diagLog('push', 'phase', data: {'k': 'v'});
    diagLogFail('push', 'phase', 'reason');
  });
}
