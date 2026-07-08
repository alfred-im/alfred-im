import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/providers/group_home_controller.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/group_home_panel.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-GROUP-HOME-002, SURF-GROUP-HOME-007, SURF-GROUP-HOME-008
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GroupHomePanel shows summary, active authors and conversation tile',
      (tester) async {
    const groupProfile = ProfileSummary(
      id: 'group-1',
      displayName: 'Famiglia',
      username: 'famiglia',
      profileKind: ProfileKind.group,
    );

    final client = createTestSupabaseClient();
    final messageService = FakeMessageService(client);
    final profileService = FakeProfileService(client)
      ..profilesById['mario'] = const ProfileSummary(
        id: 'mario',
        displayName: 'Mario',
        username: 'mario',
      );
    messageService.ownerMessagesByUserId['group-1'] = [];

    final session = await AccountSession.createForTest(
      profile: groupProfile,
      client: client,
      messageService: messageService,
      messageMediaService: MessageMediaService(client),
    );
    session.fullProfile = UserProfile(
      summary: groupProfile,
      createdAt: DateTime.utc(2026, 3, 12),
      updatedAt: DateTime.utc(2026, 3, 12),
    );
    addTearDown(() => session.disposeResources(clearAuthStorage: false));

    var conversationTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider(
          create: (_) => GroupHomeController(
            session: session,
            profile: groupProfile,
            messageService: messageService,
            profileService: profileService,
          ),
          child: GroupHomePanel(
            profile: groupProfile,
            conversationSelected: false,
            onConversationTap: () => conversationTapped = true,
            onProfileTap: () {},
            onAllowedPeopleTap: () {},
          ),
        ),
      ),
    );

    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();

    expect(find.text('Famiglia'), findsWidgets);
    expect(find.text('Persone più attive'), findsOneWidget);
    expect(find.text('0 messaggi'), findsOneWidget);
    expect(find.text('Nato il 12 mar 2026'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Famiglia').last);
    await tester.pump();
    expect(conversationTapped, isTrue);
  });
}
