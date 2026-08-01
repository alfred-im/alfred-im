// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/chat_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/fake_reception_allowlist_service.dart';

// PROM-RECEPTION-FILTER-013; SURF-CHAT-017
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownerId = 'owner-id';
  const peer = ProfileSummary(
    id: 'peer-id',
    username: 'mario',
    displayName: 'Mario Rossi',
  );
  final chatPeer = ChatPeer(profile: peer);

  late FakeMessageService messageService;
  late FakeReceptionAllowlistService allowlistService;
  late ReceptionAllowlistController allowlist;
  late MessagesController messagesController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    messageService = FakeMessageService(createTestSupabaseClient());
    allowlistService = FakeReceptionAllowlistService();
    allowlist = ReceptionAllowlistController(
      ownerId: ownerId,
      allowlistService: allowlistService,
    );
    final scope = testConversationScope(
      userId: ownerId,
      peerProfileId: peer.id,
      sessionEpoch: 1,
    );
    messagesController = MessagesController(
      scope: scope,
      messageStore: testMessageStoreFor(scope),
      userId: ownerId,
      peerProfileId: peer.id,
      messageService: messageService,
      messageMediaService: FakeMessageMediaService(),
      inboxService: FakeInboxService(),
      isScopeCommitted: () => true,
    );
    await waitForMessagesController(messagesController);
    await allowlist.load();
  });

  tearDown(() {
    messagesController.dispose();
    allowlist.dispose();
  });

  Future<void> pumpChatPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<MessagesController>.value(
              value: messagesController,
            ),
            ChangeNotifierProvider<ReceptionAllowlistController>.value(
              value: allowlist,
            ),
          ],
          child: Scaffold(body: ChatPanel(peer: chatPeer)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool textFieldEnabled(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).enabled ?? true;
  }

  testWidgets('ChatInputBar disabled when peer not in allow list', (tester) async {
    await pumpChatPanel(tester);
    expect(textFieldEnabled(tester), isFalse);
  });

  testWidgets('ChatInputBar enabled when peer is allowed', (tester) async {
    allowlistService.people = [
      AllowedPerson(entryId: 'entry-1', profile: peer),
    ];
    await allowlist.load();
    await pumpChatPanel(tester);
    expect(textFieldEnabled(tester), isTrue);
  });
}
