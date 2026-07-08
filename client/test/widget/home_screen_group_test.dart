import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/screens/home_screen.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/message_media_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/group_home_panel.dart';
import 'package:alfred_client/widgets/inbox_panel.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-GROUP-SHELL-002, SURF-GROUP-HOME-001
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen with group focus shows GroupHomePanel by default',
      (tester) async {
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
    session.fullProfile = UserProfile(
      summary: groupProfile,
      createdAt: DateTime.utc(2026, 3, 12),
      updatedAt: DateTime.utc(2026, 3, 12),
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

    expect(find.byType(GroupHomePanel), findsOneWidget);
    expect(find.byType(InboxPanel), findsNothing);
    expect(find.text('Persone più attive'), findsOneWidget);
    expect(find.text('Messaggio al gruppo (allow list)…'), findsNothing);
  });

  testWidgets('HomeScreen opens group chat from conversation tile', (tester) async {
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
    session.fullProfile = UserProfile(
      summary: groupProfile,
      createdAt: DateTime.utc(2026, 3, 12),
      updatedAt: DateTime.utc(2026, 3, 12),
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

    await tester.tap(find.text('Famiglia').last);
    await tester.pump();
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 5));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pump();

    expect(find.text('Messaggio al gruppo (allow list)…'), findsOneWidget);
    expect(auth.groupChatOpen, isTrue);
  });
}
