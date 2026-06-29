import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/open_account.dart';
import 'package:alfred_client/services/account_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountStorageService', () {
    test('round-trip open accounts', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();

      const account = OpenAccount(
        profile: ProfileSummary(
          id: 'u1',
          username: 'mario',
          displayName: 'Mario',
        ),
        refreshToken: 'rt',
      );
      await storage.upsertAccount(account);
      final loaded = await storage.loadAccounts();
      expect(loaded.length, 1);
      final decoded = OpenAccount.fromJson(
        loaded.single.toJson(),
      );
      expect(decoded.userId, account.userId);
      expect(decoded.refreshToken, account.refreshToken);
    });

    test('focus user id persists', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();
      await storage.saveFocusUserId('user-a');
      expect(await storage.loadFocusUserId(), 'user-a');
      await storage.saveFocusUserId(null);
      expect(await storage.loadFocusUserId(), isNull);
    });
  });
}
