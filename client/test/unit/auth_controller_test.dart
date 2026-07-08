import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/auth_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';

import '../support/fake_messaging_services.dart';

// spec: SURF-AUTH-002, SURF-AUTH-003, SURF-AUTH-005, PROM-MULTI-ACCOUNT-021
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthController overlay gate', () {
    test('initialize with no accounts opens mandatory overlay', () async {
      final auth = AuthController();

      await auth.initialize();

      expect(auth.showAuthOverlay, isTrue);
      expect(auth.authOverlayDismissible, isFalse);
      expect(auth.sessionReady, isTrue);
      expect(auth.isLoading, isFalse);
    });

    test('closeAuthOverlay is blocked with zero accounts', () async {
      final auth = AuthController()
        ..showAuthOverlay = true
        ..authOverlayDismissible = false;

      auth.closeAuthOverlay();

      expect(auth.showAuthOverlay, isTrue);
    });

    test('openAuthOverlay sets dismissible flag', () {
      final auth = AuthController();

      auth.openAuthOverlay(dismissible: true);

      expect(auth.showAuthOverlay, isTrue);
      expect(auth.authOverlayDismissible, isTrue);
      expect(auth.error, isNull);
    });

    test('closeAuthOverlay works when dismissible', () async {
      final client = createTestSupabaseClient();
      final session = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'user-1',
          displayName: 'Mario',
          username: 'mario',
        ),
        client: client,
      );
      final manager = AccountManager();
      manager.focusTestSession(session);

      final auth = AuthController(accountManager: manager)
        ..showAuthOverlay = true
        ..authOverlayDismissible = true;

      auth.closeAuthOverlay();

      expect(auth.showAuthOverlay, isFalse);
    });
  });

  group('AuthController validation', () {
    late AuthController auth;

    setUp(() {
      auth = AuthController()..isLoading = false;
    });

    test('signIn rejects invalid email before manager call', () async {
      await auth.signIn('not-an-email', 'password');

      expect(auth.error, 'Email non valida');
      expect(auth.isLoading, isFalse);
    });

    test('signUp rejects invalid username', () async {
      await auth.signUp(
        email: 'mario@gmail.com',
        password: 'password123',
        username: 'ab',
        displayName: 'Mario',
      );

      expect(
        auth.error,
        'Username: 3–32 caratteri, solo lettere minuscole, numeri e _',
      );
      expect(auth.isLoading, isFalse);
    });

    test('signUp rejects empty display name', () async {
      await auth.signUp(
        email: 'mario@gmail.com',
        password: 'password123',
        username: 'mario',
        displayName: '   ',
      );

      expect(auth.error, 'Inserisci un nome visualizzato');
      expect(auth.isLoading, isFalse);
    });
  });

  group('AuthController account lifecycle', () {
    test('removeAccount on last account reopens mandatory overlay', () async {
      final client = createTestSupabaseClient();
      final session = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'user-1',
          displayName: 'Mario',
          username: 'mario',
        ),
        client: client,
      );
      final manager = AccountManager();
      manager.focusTestSession(session);

      final auth = AuthController(accountManager: manager)
        ..showAuthOverlay = false
        ..sessionReady = true;

      await auth.removeAccount('user-1');

      expect(auth.showAuthOverlay, isTrue);
      expect(auth.authOverlayDismissible, isFalse);
      expect(auth.hasOpenAccounts, isFalse);
    });
  });
}
