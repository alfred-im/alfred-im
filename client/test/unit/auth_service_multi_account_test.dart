import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/models/saved_account.dart';
import 'package:alfred_client/services/account_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('multi-account storage', () {
    test('upsert keeps both accounts with latest refresh token', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();

      await storage.upsertAccount(
        SavedAccount(
          profile: const ProfileSummary(
            id: 'a',
            username: 'alice',
            displayName: 'Alice',
          ),
          refreshToken: 'refresh-a-v1',
        ),
      );
      await storage.upsertAccount(
        SavedAccount(
          profile: const ProfileSummary(
            id: 'b',
            username: 'bob',
            displayName: 'Bob',
          ),
          refreshToken: 'refresh-b-v1',
        ),
      );

      await storage.upsertAccount(
        SavedAccount(
          profile: const ProfileSummary(
            id: 'a',
            username: 'alice',
            displayName: 'Alice',
          ),
          refreshToken: 'refresh-a-v2',
        ),
      );

      final accounts = await storage.loadAccounts();
      expect(accounts.length, 2);
      expect(
        accounts.firstWhere((a) => a.userId == 'a').refreshToken,
        'refresh-a-v2',
      );
    });
  });
}
