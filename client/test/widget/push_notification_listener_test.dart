// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/screens/home_screen.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/utils/push_stub.dart';
import 'package:alfred_client/widgets/push_notification_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';
import '../support/seed_multi_account_machine.dart';

// SURF-NOTIFICATIONS-006–007 (isolato: nessun account live / test1)
class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];

  @override
  Future<ProfileSummary?> findByUsername(String username) async {
    for (final peer in _peers.values) {
      if (peer.username == username) return peer;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('open_chat intent apre la conversazione con il peer', (
    tester,
  ) async {
    const owner = ProfileSummary(
      id: 'owner-uuid',
      username: 'e2e_owner',
      displayName: 'E2E Owner',
    );
    const peer = ProfileSummary(
      id: 'peer-uuid',
      username: 'e2e_peer',
      displayName: 'E2E Peer',
    );

    final client = createTestSupabaseClient();
    final session = await AccountSession.createForTest(
      profile: owner,
      client: client,
      inboxService: FakeInboxService(
        peers: [ChatPeer(profile: peer)],
      ),
      profileService: _FakeProfileService({'peer-uuid': peer}),
      messageService: FakeMessageService(client),
    );
    final manager = AccountManager();
    manager.focusTestSession(session);
    final auth = AuthController(accountManager: manager)
      ..isLoading = false
      ..sessionReady = true;
    await seedMultiAccountMachineForTest(
      auth,
      openAccountUserIds: const ['owner-uuid'],
      focusUserId: 'owner-uuid',
    );

    addTearDown(() => session.disposeResources(clearAuthStorage: false));

    final intents = StreamController<PushOpenChatIntent>.broadcast();

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: PushNotificationListener(
            debugOpenChatIntents: intents.stream,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();

    intents.add(
      PushOpenChatIntent.fromParts(
        recipientUserId: 'owner-uuid',
        peerProfileId: 'peer-uuid',
      ),
    );
    await tester.pump();
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.text('E2E Peer').evaluate().isNotEmpty) break;
    }
    await tester.pump();

    expect(find.text('E2E Peer'), findsWidgets);
    expect(auth.activePeer, isA<ChatPeer>());
    expect(auth.activePeer?.profile.id, 'peer-uuid');

    await intents.close();
  });

  testWidgets('open_chat intent cambia focus sull account destinatario', (
    tester,
  ) async {
    const accountA = ProfileSummary(
      id: 'account-a',
      username: 'agent_a',
      displayName: 'Agent A',
    );
    const accountB = ProfileSummary(
      id: 'account-b',
      username: 'agent_b',
      displayName: 'Agent B',
    );

    final client = createTestSupabaseClient();
    final storage = AccountStorageService();
    final sessionA = await AccountSession.createForTest(
      profile: accountA,
      client: client,
      inboxService: FakeInboxService(),
      profileService: _FakeProfileService({'account-b': accountB}),
      messageService: FakeMessageService(client),
    );
    final sessionB = await AccountSession.createForTest(
      profile: accountB,
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(
        peers: [ChatPeer(profile: accountA)],
      ),
      profileService: _FakeProfileService({'account-a': accountA}),
      messageService: FakeMessageService(client),
    );

    sessionA.wireStorage(storage);
    sessionB.wireStorage(storage);
    await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
    await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
    await storage.saveFocusUserId('account-a');

    final manager = AccountManager(storage: storage);
    manager.restoreSessionForTest = (account) async {
      return account.userId == 'account-a' ? sessionA : sessionB;
    };

    final auth = AuthController(accountManager: manager);
    await auth.multiAccountAdapters.bootstrapManifest();
    auth
      ..isLoading = false
      ..sessionReady = true;

    final intents = StreamController<PushOpenChatIntent>.broadcast();

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: PushNotificationListener(
            debugOpenChatIntents: intents.stream,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();

    expect(auth.userId, 'account-a');

    final listenerState = tester.state<PushNotificationListenerState>(
      find.byType(PushNotificationListener),
    );
    await tester.runAsync(
      () => listenerState.processOpenChatForTest(
        PushOpenChatIntent.fromParts(
          recipientUserId: 'account-b',
          peerProfileId: 'account-a',
        ),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.text('Agent A').evaluate().isNotEmpty) break;
    }
    await tester.pump();

    expect(auth.userId, 'account-b');
    expect(auth.activePeer?.profile.id, 'account-a');

    await intents.close();
  });

  testWidgets(
    'tap push con A in chat con B passa a B in chat con A',
    (tester) async {
      const accountA = ProfileSummary(
        id: 'account-a',
        username: 'agent_a',
        displayName: 'Agent A',
      );
      const accountB = ProfileSummary(
        id: 'account-b',
        username: 'agent_b',
        displayName: 'Agent B',
      );

      final clientA = createTestSupabaseClient();
      final clientB = createTestSupabaseClient();
      final messageServiceA = FakeMessageService(clientA);
      final messageServiceB = FakeMessageService(clientB);

      messageServiceA.messagesByConversation[conversationKey(
        userId: 'account-a',
        peerProfileId: 'account-b',
      )] = [
        ChatMessage(
          id: 'm-a1',
          body: 'ciao da A',
          timeLabel: '12:00',
          isMine: true,
          senderId: 'account-a',
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
      ];
      messageServiceB.messagesByConversation[conversationKey(
        userId: 'account-b',
        peerProfileId: 'account-a',
      )] = [
        ChatMessage(
          id: 'm-b1',
          body: 'ciao da A',
          timeLabel: '12:01',
          isMine: false,
          senderId: 'account-a',
          createdAt: DateTime.utc(2026, 7, 19, 12, 1),
        ),
        ChatMessage(
          id: 'm-b0',
          body: 'risposta precedente B',
          timeLabel: '11:00',
          isMine: true,
          senderId: 'account-b',
          createdAt: DateTime.utc(2026, 7, 19, 11),
        ),
      ];

      final storage = AccountStorageService();
      final sessionA = await AccountSession.createForTest(
        profile: accountA,
        client: clientA,
        inboxService: FakeInboxService(
          peers: [ChatPeer(profile: accountB)],
        ),
        profileService: _FakeProfileService({'account-b': accountB}),
        messageService: messageServiceA,
      );
      final sessionB = await AccountSession.createForTest(
        profile: accountB,
        client: clientB,
        inboxService: FakeInboxService(
          peers: [ChatPeer(profile: accountA)],
        ),
        profileService: _FakeProfileService({'account-a': accountA}),
        messageService: messageServiceB,
      );

      sessionA.wireStorage(storage);
      sessionB.wireStorage(storage);
      await sessionA.persistOpenAccount(refreshToken: 'refresh-a');
      await sessionB.persistOpenAccount(refreshToken: 'refresh-b');
      await storage.saveFocusUserId('account-a');

      final manager = AccountManager(storage: storage);
      manager.restoreSessionForTest = (account) async {
        return account.userId == 'account-a' ? sessionA : sessionB;
      };

      final auth = AuthController(accountManager: manager);
      await auth.multiAccountAdapters.bootstrapManifest();
      auth
        ..isLoading = false
        ..sessionReady = true;

      auth.openConversation(ChatPeer(profile: accountB));
      expect(auth.userId, 'account-a');
      expect(auth.activePeer?.profile.id, 'account-b');

      final intents = StreamController<PushOpenChatIntent>.broadcast();

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AlfredTheme.light,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: auth),
            ],
            child: PushNotificationListener(
              debugOpenChatIntents: intents.stream,
              child: const HomeScreen(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 5));
        if (find.text('ciao da A').evaluate().isNotEmpty) break;
      }
      await tester.pump();

      final listenerState = tester.state<PushNotificationListenerState>(
        find.byType(PushNotificationListener),
      );
      await tester.runAsync(
        () => listenerState.processOpenChatForTest(
          PushOpenChatIntent.fromParts(
            recipientUserId: 'account-b',
            peerProfileId: 'account-a',
          ),
        ),
      );
      for (var i = 0; i < 500; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (auth.userId == 'account-b' &&
            auth.activePeer?.profile.id == 'account-a' &&
            auth.isConversationReady(
              session: auth.focusedSession!,
              peer: auth.activePeer!,
            )) {
          break;
        }
      }
      await tester.pump();

      expect(auth.userId, 'account-b');
      expect(auth.activePeer?.profile.id, 'account-a');
      expect(
        auth.committedScope?.ownerUserId,
        'account-b',
      );
      expect(
        auth.committedScope?.peerProfileId,
        'account-a',
      );
      expect(
        auth.isConversationReady(
          session: auth.focusedSession!,
          peer: auth.activePeer!,
        ),
        isTrue,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(seconds: 2));

      await intents.close();
    },
  );
}
