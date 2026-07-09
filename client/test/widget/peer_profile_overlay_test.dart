import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/widgets/peer_profile_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_contact_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/fake_reception_allowlist_service.dart';

// spec: PROM-PEER-PROFILE-002, 013, 014; SURF-PEER-PROFILE-015, 016
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final peer = ProfileSummary(
    id: 'peer-id',
    username: 'mario',
    displayName: 'Mario Rossi',
    pronouns: 'lui/egli',
  );

  test('toAuthorProfileSummary builds partial profile', () {
    final message = ChatMessage(
      id: 'm1',
      body: 'ciao',
      timeLabel: '12:00',
      isMine: false,
      authorDisplayName: 'Mario',
      authorProfileId: 'peer-id',
      originalAuthorId: 'peer-id',
    );

    final profile = message.toAuthorProfileSummary();

    expect(profile?.id, 'peer-id');
    expect(profile?.displayName, 'Mario');
  });

  testWidgets('PeerProfileOverlay shows identity and actions', (tester) async {
    final allowlistService = FakeReceptionAllowlistService();
    final contactService = FakeContactService();
    final allowlist = ReceptionAllowlistController(
      ownerId: 'owner-id',
      allowlistService: allowlistService,
    );
    final contacts = ContactsController(
      ownerId: 'owner-id',
      contactService: contactService,
    );

    await allowlist.load();
    await contacts.load();

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ReceptionAllowlistController>.value(
              value: allowlist,
            ),
            ChangeNotifierProvider<ContactsController>.value(
              value: contacts,
            ),
          ],
          child: PeerProfileOverlay(profile: peer),
        ),
      ),
    );

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('@mario'), findsOneWidget);
    expect(find.text('lui/egli'), findsOneWidget);
    expect(find.text('Consenti messaggi'), findsOneWidget);
    expect(find.text('Aggiungi alla rubrica'), findsOneWidget);
    expect(find.text('Inizia a chattare'), findsOneWidget);
  });

  testWidgets('Inizia a chattare closes overlay and opens conversation',
      (tester) async {
    final client = createTestSupabaseClient();
    final session = await AccountSession.createForTest(
      profile: const ProfileSummary(
        id: 'owner-id',
        displayName: 'Owner',
        username: 'owner',
      ),
      client: client,
    );
    final manager = AccountManager();
    manager.focusTestSession(session);
    final auth = AuthController(accountManager: manager);

    final allowlistService = FakeReceptionAllowlistService();
    final contactService = FakeContactService();
    final allowlist = ReceptionAllowlistController(
      ownerId: 'owner-id',
      allowlistService: allowlistService,
    );
    final contacts = ContactsController(
      ownerId: 'owner-id',
      contactService: contactService,
    );

    await allowlist.load();
    await contacts.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<ReceptionAllowlistController>.value(
            value: allowlist,
          ),
          ChangeNotifierProvider<ContactsController>.value(
            value: contacts,
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showPeerProfileOverlay(context, peer),
                    child: const Text('Apri profilo'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri profilo'));
    await tester.pumpAndSettle();

    expect(find.text('Inizia a chattare'), findsOneWidget);

    await tester.tap(find.text('Inizia a chattare'));
    await tester.pumpAndSettle();

    expect(find.text('Mario Rossi'), findsNothing);
    expect(auth.activePeer?.profileId, 'peer-id');
    expect(auth.activePeer?.displayName, 'Mario Rossi');
  });
}
