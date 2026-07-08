import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/screens/group_conversation_screen.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-GROUP-SHELL-002, SURF-GROUP-SHELL-003
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GroupConversationScreen shows allow list entry and compose hint',
      (tester) async {
    const groupProfile = ProfileSummary(
      id: 'group-1',
      displayName: 'Famiglia',
      username: 'famiglia',
      profileKind: ProfileKind.group,
    );

    final client = createTestSupabaseClient();
    final messageService = FakeMessageService(client);
    final session = await AccountSession.createForTest(
      profile: groupProfile,
      client: client,
      messageService: messageService,
      messageMediaService: MessageMediaService(client),
    );
    addTearDown(() => session.disposeResources(clearAuthStorage: false));

    var allowedPeopleTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: Scaffold(
          body: GroupConversationScreen(
            session: session,
            profile: groupProfile,
            onAllowedPeopleTap: () => allowedPeopleTapped = true,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();

    expect(find.text('Account gruppo'), findsOneWidget);
    expect(find.text('Persone consentite'), findsOneWidget);
    expect(find.text('Messaggio al gruppo (allow list)…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('Persone consentite'));
    await tester.pump();
    expect(allowedPeopleTapped, isTrue);
  });
}
