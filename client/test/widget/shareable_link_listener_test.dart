import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/providers/shareable_link_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

// spec: PROM-SHAREABLE-LINK-003, 011, 012; SURF-AUTH-014
class _FakeProfileService extends ProfileService {
  _FakeProfileService(this.peer) : super(createTestSupabaseClient());

  final ProfileSummary peer;

  @override
  Future<ProfileSummary?> findByUsername(String username) async {
    if (username == peer.username) return peer;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('fragment in ingresso apre profilo peer quando la sessione è pronta',
      (tester) async {
    const peer = ProfileSummary(
      id: 'peer-id',
      username: 'mario',
      displayName: 'Mario Rossi',
    );

    final session = await AccountSession.createForTest(
      profile: const ProfileSummary(
        id: 'owner-id',
        username: 'owner',
        displayName: 'Owner',
      ),
      client: createTestSupabaseClient(),
      profileService: _FakeProfileService(peer),
    );
    final manager = AccountManager();
    manager.focusTestSession(session);
    final auth = AuthController(accountManager: manager)..sessionReady = true;

    final link = ShareableLinkController()..applyFragment('mario');

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<ShareableLinkController>.value(value: link),
          ],
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => link.handleIfReady(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('@mario'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
