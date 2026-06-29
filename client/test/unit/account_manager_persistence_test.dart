import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/open_account.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/account_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountManager persistence (refresh scenario)', () {
    late AccountStorageService storage;
    late AccountManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = AccountStorageService();
      manager = AccountManager(storage: storage);
    });

    test('persistAllOpenAccounts saves every open session atomically', () async {
      final sessionA = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'agent-a',
          username: 'alfredagent1',
          displayName: 'Agent 1',
        ),
        refreshToken: 'refresh-agent-a',
      );
      final sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'agent-b',
          username: 'alfredagent2',
          displayName: 'Agent 2',
        ),
        refreshToken: 'refresh-agent-b',
      );

      manager.injectTestSession(sessionA);
      manager.injectTestSession(sessionB);
      await manager.persistAllOpenAccountsForTesting();

      final stored = await storage.loadAccounts();
      expect(stored.map((a) => a.userId).toSet(), {'agent-a', 'agent-b'});
      expect(
        stored.firstWhere((a) => a.userId == 'agent-a').refreshToken,
        'refresh-agent-a',
      );
      expect(
        stored.firstWhere((a) => a.userId == 'agent-b').refreshToken,
        'refresh-agent-b',
      );
    });

    test('storage retains both accounts after sequential persist (refresh input)', () async {
      await storage.saveAllAccounts([
        OpenAccount(
          profile: const ProfileSummary(
            id: 'agent-a',
            username: 'alfredagent1',
            displayName: 'Agent 1',
          ),
          refreshToken: 'refresh-agent-a',
        ),
      ]);
      await storage.saveAllAccounts([
        OpenAccount(
          profile: const ProfileSummary(
            id: 'agent-b',
            username: 'alfredagent2',
            displayName: 'Agent 2',
          ),
          refreshToken: 'refresh-agent-b',
        ),
        OpenAccount(
          profile: const ProfileSummary(
            id: 'agent-a',
            username: 'alfredagent1',
            displayName: 'Agent 1',
          ),
          refreshToken: 'refresh-agent-a',
        ),
      ]);

      final stored = await storage.loadAccounts();
      expect(stored.length, 2);
    });

    test('adding second account does not drop first from storage', () async {
      final sessionA = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'agent-a',
          username: 'alfredagent1',
          displayName: 'Agent 1',
        ),
        refreshToken: 'refresh-agent-a',
      );
      manager.injectTestSession(sessionA);
      await manager.persistAllOpenAccountsForTesting();

      final sessionB = await AccountSession.createForTest(
        profile: const ProfileSummary(
          id: 'agent-b',
          username: 'alfredagent2',
          displayName: 'Agent 2',
        ),
        refreshToken: 'refresh-agent-b',
      );
      manager.injectTestSession(sessionB);
      await manager.persistAllOpenAccountsForTesting();

      final stored = await storage.loadAccounts();
      expect(stored.length, 2);
    });
  });
}
