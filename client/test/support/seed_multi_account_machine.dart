// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/multi-account/multi_account_machine.dart';
import 'package:alfred_client/providers/auth_controller.dart';

/// Allinea [MultiAccountMachine] a sessioni iniettate in test (senza storage).
Future<void> seedMultiAccountMachineForTest(
  AuthController auth, {
  required List<String> openAccountUserIds,
  required String focusUserId,
  bool hasFocusedSession = true,
}) async {
  await auth.multiAccountMachine.send(
    ManifestLoaded(
      openAccountUserIds: openAccountUserIds,
      persistedFocusUserId: focusUserId,
    ),
  );
  await auth.multiAccountMachine.send(
    FocusActivationCompleted(hasFocusedSession: hasFocusedSession),
  );
}
