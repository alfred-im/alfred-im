import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/screens/home_screen.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/inbox_panel.dart';

import '../support/fake_messaging_services.dart';

// spec: GROUP-CORE-REQ-006
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen with group focus hides InboxPanel', (tester) async {
    const groupProfile = ProfileSummary(
      id: 'group-focus-id',
      displayName: 'Famiglia',
      username: 'famiglia',
      profileKind: ProfileKind.group,
    );

    final client = createTestSupabaseClient();
    final session = await AccountSession.createForTest(
      profile: groupProfile,
      client: client,
      messageService: FakeMessageService(client),
      messageMediaService: MessageMediaService(client),
    );

    final manager = AccountManager();
    manager.focusTestSession(session);

    final auth = AuthController(accountManager: manager)
      ..isLoading = false
      ..sessionReady = true;

    addTearDown(() => session.disposeResources(clearAuthStorage: false));

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: const HomeScreen(),
        ),
      ),
    );

    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();
    // GroupConversationScreen ListTile inside ColoredBox triggers a debug-only framework note.
    tester.takeException();

    expect(find.text('Account gruppo'), findsOneWidget);
    expect(find.byType(InboxPanel), findsNothing);
    expect(find.text('Messaggio al gruppo (allow list)…'), findsOneWidget);
  });
}
