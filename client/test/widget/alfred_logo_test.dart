import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/alfred_logo.dart';

void main() {
  testWidgets('AlfredLogo renders check icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: const Scaffold(body: AlfredLogo(size: 48)),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
