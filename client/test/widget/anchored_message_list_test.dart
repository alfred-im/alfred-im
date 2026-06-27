import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/anchored_message_list.dart';

void main() {
  testWidgets('AnchoredMessageList shows jump button when scrolled up', (
    tester,
  ) async {
    final messages = List.generate(
      40,
      (index) => ChatMessage(
        id: '$index',
        body: 'Messaggio $index',
        timeLabel: '12:00',
        isMine: index.isEven,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: AnchoredMessageList(
              messages: messages,
              isLoading: false,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable).first;
    await tester.drag(listFinder, const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('AnchoredMessageList hides jump button at bottom', (tester) async {
    final messages = [
      const ChatMessage(
        id: '1',
        body: 'Ciao',
        timeLabel: '12:00',
        isMine: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: AnchoredMessageList(
            messages: messages,
            isLoading: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });
}
