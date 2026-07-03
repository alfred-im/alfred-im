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
}
