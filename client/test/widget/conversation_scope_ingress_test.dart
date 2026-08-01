// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/chat_panel.dart';
import 'package:alfred_client/widgets/conversation_scope_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';
import '../support/seed_multi_account_machine.dart';

// SURF-CHAT-016 — header peer + back durante ingresso async (sessione assente in RAM).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const owner = ProfileSummary(
    id: 'account-a',
    username: 'agent_a',
    displayName: 'Agent A',
  );
  const peer = ProfileSummary(
    id: 'account-b',
    username: 'agent_b',
    displayName: 'Agent B',
  );

  late AccountStorageService storage;
  late AccountManager manager;
  late AccountSession sessionA;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AccountStorageService();
    manager = AccountManager(storage: storage);

    sessionA = await AccountSession.createForTest(
      profile: owner,
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(
        peers: const [ChatPeer(profile: peer)],
      ),
    );
    await installTestAuthSession(sessionA.client, userId: 'account-a');
    sessionA.wireStorage(storage);
    await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
    await storage.saveFocusUserId('account-a');

    manager.restoreSessionForTest = (account) async {
      if (account.userId == 'account-a') return sessionA;
      throw StateError('unexpected account ${account.userId}');
    };

    await manager.initialize(focusUserId: 'account-a');
    manager.clearSessionsInRamForTest();
  });

  testWidgets('ConversationScopePane senza sessione mostra header peer', (
    tester,
  ) async {
    final auth = AuthController(accountManager: manager)
      ..isLoading = false
      ..sessionReady = true;
    await seedMultiAccountMachineForTest(
      auth,
      openAccountUserIds: const ['account-a'],
      focusUserId: 'account-a',
      hasFocusedSession: false,
    );
    await auth.openConversation(const ChatPeer(profile: peer));

    addTearDown(() => sessionA.disposeResources(clearAuthStorage: false));

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: ConversationScopePane(
            auth: auth,
            session: null,
            showBackButton: true,
            onBack: () {},
            onMessagesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatIngressPanel), findsOneWidget);
    expect(find.text('Agent B'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Riconnessione'), findsNothing);
  });
}
