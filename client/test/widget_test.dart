import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/main.dart';

void main() {
  testWidgets('Alfred home shows conversation list', (WidgetTester tester) async {
    await tester.pumpWidget(const AlfredApp());
    await tester.pumpAndSettle();

    expect(find.text('Alfred'), findsWidgets);
    expect(find.text('Mario Rossi'), findsWidgets);
  });
}
