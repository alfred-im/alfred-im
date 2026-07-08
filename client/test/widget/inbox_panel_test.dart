import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/inbox_panel.dart';

ChatPeer _peer({
  required String id,
  required String name,
  String preview = 'ciao',
}) {
  return ChatPeer(
    profile: ProfileSummary(id: id, displayName: name, username: id),
    preview: preview,
    lastMessageAt: DateTime.utc(2026, 6, 29, 12),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: AlfredTheme.light, home: Scaffold(body: child));
}

// spec: PROM-LIST-FILTER-010, PROM-LIST-FILTER-011, SURF-INBOX-001, SURF-ALLOWLIST-001
void main() {
  testWidgets('InboxPanel desktop hides search until lens tap', (tester) async {
    var searchQuery = '';
    await tester.pumpWidget(
      _wrap(
        InboxPanel(
          selectedPeerId: null,
          peers: const [],
          isLoading: false,
          onSelected: (_) {},
          onSearchChanged: (value) => searchQuery = value,
          onContactsTap: () {},
          showTopBar: false,
        ),
      ),
    );

    expect(find.text('Conversazioni'), findsOneWidget);
    expect(find.text('Cerca messaggi'), findsNothing);

    await tester.tap(find.byTooltip('Cerca messaggi'));
    await tester.pump();

    expect(find.text('Cerca messaggi'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'mario');
    expect(searchQuery, 'mario');
  });

  testWidgets('InboxPanel mobile header exposes allow list and contacts',
      (tester) async {
    var allowedTapped = false;
    var contactsTapped = false;

    await tester.pumpWidget(
      _wrap(
        InboxPanel(
          selectedPeerId: null,
          peers: const [],
          isLoading: false,
          onSelected: (_) {},
          onSearchChanged: (_) {},
          onContactsTap: () => contactsTapped = true,
          onAllowedPeopleTap: () => allowedTapped = true,
          showTopBar: true,
        ),
      ),
    );

    expect(find.text('Alfred'), findsOneWidget);

    await tester.tap(find.byTooltip('Persone consentite'));
    await tester.pump();
    expect(allowedTapped, isTrue);

    await tester.tap(find.byTooltip('Contatti'));
    await tester.pump();
    expect(contactsTapped, isTrue);
  });

  testWidgets('InboxPanel shows empty state and peer rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboxPanel(
          selectedPeerId: 'peer-b',
          peers: [
            _peer(id: 'peer-a', name: 'Alice'),
            _peer(id: 'peer-b', name: 'Bob', preview: 'ultimo'),
          ],
          isLoading: false,
          onSelected: (_) {},
          onSearchChanged: (_) {},
          onContactsTap: () {},
          showTopBar: false,
        ),
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('ultimo'), findsOneWidget);
  });

  testWidgets('InboxPanel empty list shows compose hint', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboxPanel(
          selectedPeerId: null,
          peers: const [],
          isLoading: false,
          onSelected: (_) {},
          onSearchChanged: (_) {},
          onContactsTap: () {},
          showTopBar: false,
        ),
      ),
    );

    expect(
      find.textContaining('Nessun messaggio'),
      findsOneWidget,
    );
  });
}
