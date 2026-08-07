// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/data/emoji_catalog.dart';
import 'package:alfred_client/machines/messaging/conversation_message_store.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/message_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';

void main() {
  testWidgets('message action menu shows scrollable emoji catalog', (
    tester,
  ) async {
    final scope = testConversationScope(userId: 'u1', peerProfileId: 'p1');
    final store = ConversationMessageStore()..bindCommittedScope(scope);
    final messageService = FakeMessageService(createTestSupabaseClient());
    final message = ChatMessage(
      id: 'm1',
      body: 'ciao',
      timeLabel: '12:00',
      isMine: false,
      logicalMessageId: '11111111-1111-1111-1111-111111111111',
    );

    late MessagesController controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              controller = MessagesController(
                scope: scope,
                messageStore: store,
                userId: 'u1',
                peerProfileId: 'p1',
                messageService: messageService,
                messageMediaService: FakeMessageMediaService(),
                inboxService: FakeInboxService(),
                isScopeCommitted: () => true,
              );
              return TextButton(
                onPressed: () => showMessageActionMenu(
                  context: context,
                  message: message,
                  controller: controller,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Reaction'), findsOneWidget);
    expect(find.text(EmojiCatalog.all.first), findsWidgets);
    expect(find.byType(Scrollable), findsWidgets);

    controller.dispose();
  });
}
