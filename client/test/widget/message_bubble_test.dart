// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/message_bubble.dart';

void main() {
  testWidgets('MessageBubble renders body and checkmarks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '1',
              body: 'Ciao mondo',
              timeLabel: '12:30',
              isMine: true,
              status: MessageStatus.read,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ciao mondo'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('MessageBubble renders delivered checkmarks as double grey', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '3',
              body: 'Consegnato',
              timeLabel: '12:32',
              isMine: true,
              status: MessageStatus.delivered,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.done_all), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);
  });

  testWidgets('MessageBubble renders gif image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '2',
              body: '',
              timeLabel: '12:31',
              isMine: false,
              contentType: MessageContentType.gif,
              mediaUrl: 'https://example.com/test.gif',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('12:31'), findsOneWidget);
  });

  testWidgets('MessageBubble renders photo image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '2b',
              body: 'Didascalia',
              timeLabel: '12:31',
              isMine: false,
              contentType: MessageContentType.image,
              mediaUrl: 'https://example.com/test.jpg',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Didascalia'), findsOneWidget);
  });

  testWidgets('MessageBubble renders pending video placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '2c',
              body: '',
              timeLabel: '12:31',
              isMine: true,
              status: MessageStatus.pending,
              contentType: MessageContentType.video,
              mediaUrl: 'pending://client-id',
              durationSeconds: 8,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('MessageBubble renders voice player', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '4',
              body: '',
              timeLabel: '12:33',
              isMine: true,
              contentType: MessageContentType.voice,
              mediaUrl: 'https://example.com/note.webm',
              durationSeconds: 15,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('0:15'), findsOneWidget);
  });

  testWidgets('MessageBubble renders location map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            message: ChatMessage(
              id: '5',
              body: '',
              timeLabel: '12:34',
              isMine: false,
              contentType: MessageContentType.location,
              latitude: 45.4642,
              longitude: 9.19,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.textContaining('45.46420°N'), findsOneWidget);
    expect(find.text('Tocca per aprire la mappa'), findsOneWidget);
  });

  testWidgets('MessageBubble renders read checkmarks from mailbox readAt', (
    tester,
  ) async {
    final readAt = DateTime.utc(2026, 7, 4, 12);
    final message = ChatMessage(
      id: '6',
      body: 'Letto',
      timeLabel: '12:35',
      isMine: true,
      status: MessageStatus.read,
      readAt: readAt,
      deliveredAt: readAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('MessageBubble maps deliveredAt to double grey checkmarks', (
    tester,
  ) async {
    final deliveredAt = DateTime.utc(2026, 7, 4, 12);
    final message = ChatMessage.fromJson(
      json: {
        'id': '7',
        'body': 'Consegnato mailbox',
        'created_at': deliveredAt.toIso8601String(),
        'author_id': 'me',
        'delivered_at': deliveredAt.toIso8601String(),
      },
      currentUserId: 'me',
    ).copyWith(timeLabel: '12:36');

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: MessageBubble(message: message),
        ),
      ),
    );

    expect(message.status, MessageStatus.delivered);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('MessageBubble shows author header with readable name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            showAuthorLabel: true,
            message: ChatMessage(
              id: '8',
              body: 'Messaggio di gruppo',
              timeLabel: '12:37',
              isMine: false,
              authorDisplayName: 'Giulia Bianchi',
              authorProfileId: 'user-g',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Giulia Bianchi'), findsOneWidget);
    expect(find.text('@giulia'), findsNothing);
    expect(find.text('Messaggio di gruppo'), findsOneWidget);
  });

  testWidgets('MessageBubble hides author header for own messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(
          body: MessageBubble(
            showAuthorLabel: true,
            message: ChatMessage(
              id: '9',
              body: 'Mio messaggio',
              timeLabel: '12:38',
              isMine: true,
              authorDisplayName: 'Tu',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tu'), findsNothing);
    expect(find.text('Mio messaggio'), findsOneWidget);
  });
}
