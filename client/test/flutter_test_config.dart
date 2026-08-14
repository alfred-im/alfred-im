// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'support/instance_test_runtime.dart';

/// Default deploy + instance runtime for unit/widget tests (no real backend).
Future<void> testExecutable(Future<void> Function() testMain) async {
  setUpAll(installTestDeployAndInstance);
  tearDownAll(resetTestDeployAndInstance);
  await testMain();
}
