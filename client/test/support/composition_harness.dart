// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/utils/conversation_session_access.dart';
import 'session_scope_keys_test_helpers.dart';

import 'fake_messaging_services.dart';
import 'wiring_test_fixtures.dart';

/// Servizi fake per sessione — come [AccountManager.restoreSessionForTest] in produzione.
class CompositionSessionServices {
  CompositionSessionServices({
    required this.session,
    required this.messageService,
  });

  final AccountSession session;
  final FakeMessageService messageService;
}

/// Auth multi-account wired con un [FakeMessageService] per ogni restore sessione.
Future<({
  AuthController auth,
  Map<AccountSession, FakeMessageService> servicesBySession,
})> createCompositionAuth({
  required List<({String userId, String username})> accounts,
  required String focusUserId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final servicesBySession = <AccountSession, FakeMessageService>{};
  final storage = await _seedStorage(accounts, focusUserId);

  final manager = AccountManager(storage: storage)
    ..restoreSessionForTest = (account) async {
      final client = createTestSupabaseClient();
      await installTestAuthSession(client, userId: account.userId);
      final messageService = FakeMessageService(client);
      final session = await AccountSession.createForTest(
        profile: account.profile,
        client: client,
        messageService: messageService,
        messageMediaService: MessageMediaService(client),
        inboxService: FakeInboxService(),
      );
      servicesBySession[session] = messageService;
      return session;
    };

  final auth = await createWiredAuthController(manager: manager);
  await auth.initialize();
  return (auth: auth, servicesBySession: servicesBySession);
}

Future<AccountStorageService> _seedStorage(
  List<({String userId, String username})> accounts,
  String focusUserId,
) async {
  final storage = AccountStorageService();
  await seedAccountsInStorage(
    storage: storage,
    accounts: [
      for (final a in accounts)
        openAccount(userId: a.userId, username: a.username),
    ],
    focusUserId: focusUserId,
  );
  return storage;
}

/// Round-trip focus: focusUserId → otherUserId → focusUserId.
Future<void> roundTripFocus(
  AuthController auth, {
  required String focusUserId,
  required String otherUserId,
}) async {
  await auth.setFocus(otherUserId);
  await auth.setFocus(focusUserId);
}

/// Harness che rispecchia [_ChatWithMessages] in `home_screen.dart`:
/// chiave esterna su scope sessione + Provider con sessione viva e [hasValidSession].
class SessionScopedMessagesHarness extends StatefulWidget {
  const SessionScopedMessagesHarness({
    super.key,
    required this.auth,
    required this.peer,
    required this.scopeKeyFor,
    this.onControllerCreated,
  });

  final AuthController auth;
  final ChatPeer peer;
  final Key Function(AccountSession session, String peerProfileId) scopeKeyFor;
  final void Function(MessagesController controller)? onControllerCreated;

  @override
  State<SessionScopedMessagesHarness> createState() =>
      _SessionScopedMessagesHarnessState();
}

class _SessionScopedMessagesHarnessState
    extends State<SessionScopedMessagesHarness> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final session = widget.auth.focusedSession;
        if (session == null) {
          return const Text('no-session', textDirection: TextDirection.ltr);
        }

        return _SessionScopedMessagesBody(
          key: widget.scopeKeyFor(session, widget.peer.profileId),
          auth: widget.auth,
          session: session,
          peer: widget.peer,
          onControllerCreated: widget.onControllerCreated,
        );
      },
    );
  }
}

class _SessionScopedMessagesBody extends StatelessWidget {
  const _SessionScopedMessagesBody({
    super.key,
    required this.auth,
    required this.session,
    required this.peer,
    this.onControllerCreated,
  });

  final AuthController auth;
  final AccountSession session;
  final ChatPeer peer;
  final void Function(MessagesController controller)? onControllerCreated;

  bool _focusedSessionValid() {
    final live = auth.focusedSession;
    if (live == null || live.userId != session.userId) return false;
    return isMessagingSessionReady(
      client: live.client,
      ownerUserId: live.userId,
      peerProfileId: peer.profileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveSession = auth.focusedSession;
    if (liveSession == null || liveSession.userId != session.userId) {
      return const Text('reconnecting', textDirection: TextDirection.ltr);
    }

    return ChangeNotifierProvider(
      create: (_) {
        final scope = testConversationScope(
          userId: liveSession.userId,
          peerProfileId: peer.profileId,
          sessionEpoch: 1,
        );
        final controller = MessagesController(
          scope: scope,
          messageStore: testMessageStoreFor(scope),
          userId: liveSession.userId,
          peerProfileId: peer.profileId,
          messageService: liveSession.messageService,
          messageMediaService: liveSession.messageMediaService,
          inboxService: liveSession.inboxService,
          hasValidSession: _focusedSessionValid,
          isScopeCommitted: () => true,
        );
        onControllerCreated?.call(controller);
        return controller;
      },
      child: Consumer<MessagesController>(
        builder: (context, controller, _) {
          return Column(
            children: [
              Text(
                controller.error ?? 'ready',
                textDirection: TextDirection.ltr,
              ),
              TextButton(
                onPressed: () => controller.send('composition-ping'),
                child: const Text('send'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chiave produzione — esportata per test COMP-002.
Key productionMessagesScopeKey(AccountSession session, String peerId) =>
    messagesSessionKey(session, peerId);

/// Chiave legacy che mascherava il bug (solo userId + peer).
Key legacyMessagesScopeKey(AccountSession session, String peerId) =>
    ValueKey('${session.userId}-$peerId');

/// Pump bounded — evita hang di [WidgetTester.pumpAndSettle] con timer/realtime.
Future<void> pumpCompositionFrames(
  WidgetTester tester, {
  int count = 20,
  Duration step = const Duration(milliseconds: 16),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

/// Tap send + pump fino a completamento async del coordinator.
Future<void> tapSendAndDrain(WidgetTester tester) async {
  await tester.tap(find.text('send'));
  await pumpCompositionFrames(tester, count: 80);
}
