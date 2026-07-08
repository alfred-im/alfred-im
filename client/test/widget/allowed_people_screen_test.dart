import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:alfred_client/screens/allowed_people_screen.dart';
import 'package:alfred_client/theme/alfred_theme.dart';

import '../support/fake_reception_allowlist_service.dart';

Future<void> _waitForAllowlist(ReceptionAllowlistController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

// spec: SURF-ALLOWLIST-001, PROM-RECEPTION-FILTER-008
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AllowedPeopleScreen shows title and empty state guidance',
      (tester) async {
    final service = FakeReceptionAllowlistService();
    final controller = ReceptionAllowlistController(
      ownerId: 'owner-id',
      allowlistService: service,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<ReceptionAllowlistController>.value(
          value: controller,
          child: const AllowedPeopleScreen(),
        ),
      ),
    );

    await _waitForAllowlist(controller);
    await tester.pump();

    expect(find.text('Persone consentite'), findsOneWidget);
    expect(find.text('Cerca nella lista'), findsNothing);

    await tester.tap(find.byTooltip('Cerca nella lista'));
    await tester.pump();

    expect(find.text('Cerca nella lista'), findsWidgets);
    expect(
      find.text(
        'Nessuno può consegnarti messaggi finché non aggiungi qualcuno a questa lista.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AllowedPeopleScreen lists allowed profiles', (tester) async {
    const alice = ProfileSummary(
      id: 'alice-id',
      displayName: 'Alice',
      username: 'alice',
    );
    final service = FakeReceptionAllowlistService()
      ..people = [
        const AllowedPerson(entryId: 'entry-1', profile: alice),
      ];
    final controller = ReceptionAllowlistController(
      ownerId: 'owner-id',
      allowlistService: service,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<ReceptionAllowlistController>.value(
          value: controller,
          child: const AllowedPeopleScreen(),
        ),
      ),
    );

    await _waitForAllowlist(controller);
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.byTooltip('Rimuovi'), findsOneWidget);
  });
}
