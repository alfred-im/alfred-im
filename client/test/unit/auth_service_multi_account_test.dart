import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/saved_account.dart';
import 'package:alfred_client/services/account_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('multi-account storage', () {
    test('upsert keeps both accounts with latest refresh token', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();

      await storage.upsertAccount(
        const SavedAccount(
          userId: 'a',
          username: 'alice',
          refreshToken: 'refresh-a-v1',
          displayName: 'Alice',
        ),
      );
      await storage.upsertAccount(
        const SavedAccount(
          userId: 'b',
          username: 'bob',
          refreshToken: 'refresh-b-v1',
          displayName: 'Bob',
        ),
      );

      await storage.upsertAccount(
        const SavedAccount(
          userId: 'a',
          username: 'alice',
          refreshToken: 'refresh-a-v2',
          displayName: 'Alice',
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
