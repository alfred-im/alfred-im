import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:alfred_client/screens/contacts_screen.dart';
import 'package:alfred_client/theme/alfred_theme.dart';

import '../support/fake_contact_service.dart';

Future<void> _waitForContacts(ContactsController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

// spec: SURF-CONTACTS-001, SURF-CONTACTS-003
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ContactsScreen hides search until lens tap', (tester) async {
    final service = FakeContactService();
    final controller = ContactsController(
      ownerId: 'owner-id',
      contactService: service,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<ContactsController>.value(
          value: controller,
          child: const ContactsScreen(),
        ),
      ),
    );

    await _waitForContacts(controller);
    await tester.pump();

    expect(find.text('Contatti'), findsOneWidget);
    expect(find.text('Cerca contatto'), findsNothing);

    await tester.tap(find.byTooltip('Cerca contatto'));
    await tester.pump();

    expect(find.text('Cerca contatto'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'ali');
    expect(controller.filteredContacts, isEmpty);
  });

  testWidgets('ContactsScreen filters list when search is open', (tester) async {
    final service = FakeContactService()
      ..contacts = [
        Contact(
          id: 'c1',
          ownerId: 'owner-id',
          protocol: ContactProtocol.internal,
          linkedProfileId: 'p1',
          displayName: 'Alice',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        Contact(
          id: 'c2',
          ownerId: 'owner-id',
          protocol: ContactProtocol.internal,
          linkedProfileId: 'p2',
          displayName: 'Bob',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
    final controller = ContactsController(
      ownerId: 'owner-id',
      contactService: service,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<ContactsController>.value(
          value: controller,
          child: const ContactsScreen(),
        ),
      ),
    );

    await _waitForContacts(controller);
    await tester.pump();

    await tester.tap(find.byTooltip('Cerca contatto'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
  });
}
