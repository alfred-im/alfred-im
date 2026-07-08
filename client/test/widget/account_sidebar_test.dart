import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:alfred_client/theme/alfred_theme.dart';
import 'package:alfred_client/widgets/account_sidebar.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-ACCOUNT-SIDEBAR-013
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AccountSidebar shows Gruppo badge for focused group account',
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
    );
    session.fullProfile = UserProfile(
      summary: groupProfile,
      createdAt: DateTime.utc(2026, 6, 29),
      updatedAt: DateTime.utc(2026, 6, 29),
    );

    final manager = AccountManager();
    manager.focusTestSession(session);

    final auth = AuthController(accountManager: manager)
      ..isLoading = false
      ..sessionReady = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: AccountSidebar(
            onEditProfile: () {},
            onAddAccount: () {},
          ),
        ),
      ),
    );

    expect(find.text('Famiglia'), findsOneWidget);
    expect(find.text('Gruppo'), findsOneWidget);
  });

  testWidgets('AccountSidebar shows Gruppo badge on other group accounts',
      (tester) async {
    const userProfile = ProfileSummary(
      id: 'user-focus-id',
      displayName: 'Mario',
      username: 'mario',
    );
    const groupProfile = ProfileSummary(
      id: 'group-other-id',
      displayName: 'Team',
      username: 'team',
      profileKind: ProfileKind.group,
    );

    final client = createTestSupabaseClient();
    final storage = AccountStorageService();
    final userSession = await AccountSession.createForTest(
      profile: userProfile,
      client: client,
    );
    final groupSession = await AccountSession.createForTest(
      profile: groupProfile,
      client: client,
    );
    userSession.fullProfile = UserProfile(
      summary: userProfile,
      createdAt: DateTime.utc(2026, 6, 29),
      updatedAt: DateTime.utc(2026, 6, 29),
    );

    final manager = AccountManager(storage: storage);
    manager.focusTestSession(userSession);
    await userSession.persistOpenAccount(refreshToken: 'rt-user');
    groupSession.wireStorage(storage);
    await groupSession.persistOpenAccount(refreshToken: 'rt-group');
    await manager.syncManifestFromStorageForTest();

    final auth = AuthController(accountManager: manager)
      ..isLoading = false
      ..sessionReady = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AlfredTheme.light,
        home: ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: AccountSidebar(
            onEditProfile: () {},
            onAddAccount: () {},
          ),
        ),
      ),
    );

    expect(find.text('Altri account'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Gruppo'), findsOneWidget);
  });
}
