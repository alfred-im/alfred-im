import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';

ChatPeer _peer(String id) {
  return ChatPeer(
    profile: ProfileSummary(id: id, displayName: 'Peer $id'),
    preview: 'ciao',
    lastMessageAt: DateTime.utc(2026, 6, 29),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountManager per-account view state', () {
    late AccountManager manager;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
    });

    test('openConversation and setFocus preserve view per account', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');

      await manager.setFocus('account-a');
      manager.openConversation(_peer('account-b'));

      await manager.setFocus('account-b');
      manager.openConversation(_peer('account-a'));

      await manager.setFocus('account-a');
      expect(manager.viewState.activePeer?.profileId, 'account-b');

      await manager.setFocus('account-b');
      expect(manager.viewState.activePeer?.profileId, 'account-a');
    });

    test('setFocus does not clear other accounts view state', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');

      await manager.setFocus('account-a');
      manager.openConversation(_peer('account-b'));

      await manager.setFocus('account-b');
      expect(manager.viewState.activePeer, isNull);

      await manager.setFocus('account-a');
      expect(manager.viewState.activePeer?.profileId, 'account-b');
    });

    test('removeAccount drops saved view for that user', () async {
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');

      await manager.setFocus('account-a');
      manager.openConversation(_peer('account-b'));

      await manager.removeAccount('account-a');
      await manager.setFocus('account-b');

      expect(manager.viewState.activePeer, isNull);
    });
  });
}
