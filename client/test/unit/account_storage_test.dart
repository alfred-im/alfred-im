import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/saved_account.dart';
import 'package:alfred_client/services/account_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountStorageService', () {
    test('upsert and load accounts', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = AccountStorageService();

      await storage.upsertAccount(
        const SavedAccount(
          userId: 'u1',
          email: 'a@test.com',
          refreshToken: 'rt1',
          displayName: 'Alice',
        ),
      );
      await storage.upsertAccount(
        const SavedAccount(
          userId: 'u2',
          email: 'b@test.com',
          refreshToken: 'rt2',
          displayName: 'Bob',
        ),
      );

      var accounts = await storage.loadAccounts();
      expect(accounts.length, 2);

      await storage.upsertAccount(
        const SavedAccount(
          userId: 'u1',
          email: 'a@test.com',
          refreshToken: 'rt1-new',
          displayName: 'Alice Updated',
        ),
      );
      accounts = await storage.loadAccounts();
      expect(accounts.length, 2);
      expect(accounts.firstWhere((a) => a.userId == 'u1').displayName,
          'Alice Updated');

      await storage.removeAccount('u1');
      accounts = await storage.loadAccounts();
      expect(accounts.length, 1);
      expect(accounts.single.userId, 'u2');
    });

    test('serializes roundtrip', () {
      const account = SavedAccount(
        userId: 'u1',
        email: 'a@test.com',
        refreshToken: 'rt',
        displayName: 'Alice',
      );
      final decoded = SavedAccount.fromJson(
        jsonDecode(jsonEncode(account.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.email, account.email);
    });
  });
}
