// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/open_account.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

import 'fake_messaging_services.dart';

/// AuthController con stack produzione (coordinator + effects live) e restore
/// sessioni senza rete — mock solo al confine GoTrue.
Future<AuthController> createWiredAuthController({
  AccountManager? manager,
}) async {
  final accountManager = manager ?? AccountManager();
  accountManager.restoreSessionForTest ??= (account) async {
    final client = createTestSupabaseClient();
    await installTestAuthSession(client, userId: account.userId);
    return AccountSession.createForTest(
      profile: account.profile,
      client: client,
    );
  };

  final auth = AuthController(accountManager: accountManager);
  return auth;
}

Future<void> seedAccountsInStorage({
  required AccountStorageService storage,
  required List<OpenAccount> accounts,
  required String focusUserId,
}) async {
  for (final account in accounts) {
    await storage.upsertAccount(account);
  }
  await storage.saveFocusUserId(focusUserId);
}

OpenAccount openAccount({
  required String userId,
  required String username,
  String refreshToken = 'refresh-test',
}) {
  return OpenAccount(
    profile: ProfileSummary(
      id: userId,
      username: username,
      displayName: username,
    ),
    refreshToken: refreshToken,
  );
}
