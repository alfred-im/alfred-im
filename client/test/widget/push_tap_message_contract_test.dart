// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/screens/home_screen.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/utils/push_stub.dart';
import 'package:alfred_client/widgets/chat_panel.dart';
import 'package:alfred_client/widgets/push_notification_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

/// Contratto utente — tap push con messaggi corretti (PROM-CONVERSATION-SCOPE-006)
///
/// Scenario: A in chat con B → notifica su B → tap → B in chat con A.
///
/// INV-PUSH-MSG-1: nessun testo della mailbox A|B visibile su B|A.
/// INV-PUSH-MSG-2: messaggi B|A presenti con lato corretto (A ricevuto, B inviato).
/// INV-PUSH-MSG-3: nessun messaggio da altre conversazioni di B (es. B|Y).
const _poisonAtoB = 'VELENO_SOLO_MAILBOX_A_VERSO_B';
const _poisonBtoY = 'VELENO_MAILBOX_B_VERSO_Y';
const _msgFromA = 'ciao da A';
const _msgFromB = 'risposta precedente B';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'INV-PUSH-MSG tap push mostra solo messaggi mailbox B verso A',
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
      const accountY = ProfileSummary(
        id: 'account-y',
        username: 'agent_y',
        displayName: 'Agent Y',
      );

      final clientA = createTestSupabaseClient();
      final clientB = createTestSupabaseClient();
      await installTestAuthSession(clientA, userId: 'account-a');
      await installTestAuthSession(clientB, userId: 'account-b');
      final messageServiceA = DelayedFakeMessageService(
        clientA,
        fetchDelay: const Duration(milliseconds: 120),
      );
      final messageServiceB = FakeMessageService(clientB);

      messageServiceA.messagesByConversation[conversationKey(
        userId: 'account-a',
        peerProfileId: 'account-b',
      )] = [
        ChatMessage(
          id: 'm-a-poison',
          body: _poisonAtoB,
          timeLabel: '12:00',
          isMine: true,
          senderId: 'account-a',
          createdAt: DateTime.utc(2026, 7, 19, 12),
        ),
        ChatMessage(
          id: 'm-a1',
          body: _msgFromA,
          timeLabel: '12:01',
          isMine: true,
          senderId: 'account-a',
          createdAt: DateTime.utc(2026, 7, 19, 12, 1),
        ),
      ];
      messageServiceB.messagesByConversation[conversationKey(
        userId: 'account-b',
        peerProfileId: 'account-a',
      )] = [
        ChatMessage(
          id: 'm-b1',
          body: _msgFromA,
          timeLabel: '12:01',
          isMine: false,
          senderId: 'account-a',
          createdAt: DateTime.utc(2026, 7, 19, 12, 1),
        ),
        ChatMessage(
          id: 'm-b0',
          body: _msgFromB,
          timeLabel: '11:00',
          isMine: true,
          senderId: 'account-b',
          createdAt: DateTime.utc(2026, 7, 19, 11),
        ),
      ];
      messageServiceB.messagesByConversation[conversationKey(
        userId: 'account-b',
        peerProfileId: 'account-y',
      )] = [
        ChatMessage(
          id: 'm-by',
          body: _poisonBtoY,
          timeLabel: '10:00',
          isMine: true,
          senderId: 'account-b',
          createdAt: DateTime.utc(2026, 7, 19, 10),
        ),
      ];

      final storage = AccountStorageService();
      final sessionA = await AccountSession.createForTest(
        profile: accountA,
        client: clientA,
        inboxService: FakeInboxService(
          peers: [ChatPeer(profile: accountB)],
        ),
        profileService: _FakeProfileService({
          'account-b': accountB,
          'account-y': accountY,
        }),
      );
      final sessionB = await AccountSession.createForTest(
        profile: accountB,
        client: clientB,
        inboxService: FakeInboxService(
          peers: [
            ChatPeer(profile: accountA),
            ChatPeer(profile: accountY),
          ],
        ),
        profileService: _FakeProfileService({
          'account-a': accountA,
          'account-y': accountY,
        }),
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
      await auth.initialize();

      auth.openConversation(ChatPeer(profile: accountB));

      final intents = StreamController<PushOpenChatIntent>.broadcast();
      addTearDown(intents.close);

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

      // Avvia fetch lento su A|B (controller ancora montato).
      await tester.pump(const Duration(milliseconds: 20));

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

      MessagesController? messagesController;
      for (var i = 0; i < 800; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (find.byType(ChatPanel).evaluate().isEmpty) continue;
        messagesController = Provider.of<MessagesController>(
          tester.element(find.byType(ChatPanel)),
          listen: false,
        );
        if (!messagesController.isLoading &&
            messagesController.messages.isNotEmpty &&
            auth.userId == 'account-b' &&
            auth.activePeer?.profile.id == 'account-a') {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.userId, 'account-b');
      expect(auth.activePeer?.profile.id, 'account-a');
      expect(messagesController, isNotNull);

      final bodies = messagesController!.messages.map((m) => m.body).toList();

      // INV-PUSH-MSG-2: mailbox B|A
      expect(bodies, contains(_msgFromA));
      expect(bodies, contains(_msgFromB));
      expect(
        messagesController.messages
            .firstWhere((m) => m.body == _msgFromA)
            .isMine,
        isFalse,
      );
      expect(
        messagesController.messages
            .firstWhere((m) => m.body == _msgFromB)
            .isMine,
        isTrue,
      );

      // INV-PUSH-MSG-1 e INV-PUSH-MSG-3: nessun bleed da altre mailbox
      expect(bodies, isNot(contains(_poisonAtoB)));
      expect(bodies, isNot(contains(_poisonBtoY)));

      await tester.pump(const Duration(seconds: 2));
    },
  );
}
