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
}
