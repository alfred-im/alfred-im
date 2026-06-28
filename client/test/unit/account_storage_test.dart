import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/profile_summary.dart';
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
        SavedAccount(
          profile: const ProfileSummary(
            id: 'u1',
            username: 'alice',
            displayName: 'Alice',
          ),
          refreshToken: 'rt1',
        ),
      );
      await storage.upsertAccount(
        SavedAccount(
          profile: const ProfileSummary(
            id: 'u2',
            username: 'bob',
            displayName: 'Bob',
          ),
          refreshToken: 'rt2',
        ),
      );

      var accounts = await storage.loadAccounts();
      expect(accounts.length, 2);

      await storage.upsertAccount(
        SavedAccount(
          profile: const ProfileSummary(
            id: 'u1',
            username: 'alice',
            displayName: 'Alice Updated',
          ),
          refreshToken: 'rt1-new',
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
        profile: ProfileSummary(
          id: 'u1',
          username: 'alice',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/a.jpg',
          pronouns: 'lei/ella',
        ),
        refreshToken: 'rt',
      );
      final decoded = SavedAccount.fromJson(
        jsonDecode(jsonEncode(account.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.username, account.username);
      expect(decoded.avatarUrl, account.avatarUrl);
      expect(decoded.pronouns, account.pronouns);
    });
  });
}
