// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/peer_relationship.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:alfred_client/widgets/chat_ingress_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fake_contact_service.dart';
import '../support/fake_reception_allowlist_service.dart';

// SURF-PEER-PROFILE-003, 004 — azioni peer da header chat 1:1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const peerProfile = ProfileSummary(
    id: 'peer-id',
    username: 'mario',
    displayName: 'Mario Rossi',
  );
  const peer = ChatPeer(
    profile: peerProfile,
    relationship: PeerRelationship(inContacts: false, isAllowed: false),
  );

  testWidgets('header chat 1:1 mostra menu rubrica e consenso', (tester) async {
    final auth = AuthController();
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
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ReceptionAllowlistController>.value(
              value: allowlist,
            ),
            ChangeNotifierProvider<ContactsController>.value(
              value: contacts,
            ),
          ],
          child: const Scaffold(
            body: ChatPanelHeader(
              peer: peer,
              showBackButton: false,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Aggiungi alla rubrica'), findsOneWidget);
    expect(find.text('Consenti'), findsOneWidget);
  });

  testWidgets('menu header aggiunge rubrica e consente messaggi', (tester) async {
    final auth = AuthController();
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
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ReceptionAllowlistController>.value(
              value: allowlist,
            ),
            ChangeNotifierProvider<ContactsController>.value(
              value: contacts,
            ),
          ],
          child: const Scaffold(
            body: ChatPanelHeader(
              peer: peer,
              showBackButton: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi alla rubrica'));
    await tester.pumpAndSettle();

    expect(contacts.contactForProfileId('peer-id'), isNotNull);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consenti'));
    await tester.pumpAndSettle();

    expect(allowlist.isProfileAllowed('peer-id'), isTrue);
  });

  testWidgets('menu header mostra rimuovi se peer già in rubrica', (tester) async {
    final auth = AuthController();
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

    const peerInRubrica = ChatPeer(
      profile: peerProfile,
      relationship: PeerRelationship(inContacts: true, isAllowed: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ReceptionAllowlistController>.value(
              value: allowlist,
            ),
            ChangeNotifierProvider<ContactsController>.value(
              value: contacts,
            ),
          ],
          child: const Scaffold(
            body: ChatPanelHeader(
              peer: peerInRubrica,
              showBackButton: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Rimuovi dalla rubrica'), findsOneWidget);
    expect(find.text('Aggiungi alla rubrica'), findsNothing);
  });

  test('fromInboxRow mappa flag relazione peer', () {
    final parsed = ChatPeer.fromInboxRow({
      'protocol': 'internal',
      'display_name': 'Mario Rossi',
      'peer_profile_id': 'peer-id',
      'peer_in_contacts': true,
      'peer_is_allowed': false,
      'last_message_preview': 'Ciao',
      'unread_count': 0,
    });

    expect(parsed.peerInContacts, isTrue);
    expect(parsed.peerIsAllowed, isFalse);
  });

  testWidgets('header gruppo non mostra menu peer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatPanelHeader(
            profile: peerProfile,
            showBackButton: false,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}
