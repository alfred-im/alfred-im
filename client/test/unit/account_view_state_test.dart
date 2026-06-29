import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/account_view_state.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';

ChatPeer _peer(String id, {String preview = 'ciao'}) {
  return ChatPeer(
    profile: ProfileSummary(id: id, displayName: 'Peer $id'),
    preview: preview,
    lastMessageAt: DateTime.utc(2026, 6, 29),
  );
}

void main() {
  group('AccountViewState', () {
    test('openChat sets peer and hides inbox on mobile', () {
      const empty = AccountViewState();
      final peer = _peer('p1');
      final opened = empty.openChat(peer);

      expect(opened.activePeer, peer);
      expect(opened.showInboxOnMobile, isFalse);
    });

    test('clearConversation resets view', () {
      final opened = const AccountViewState().openChat(_peer('p1'));
      final cleared = opened.clearConversation();

      expect(cleared.activePeer, isNull);
      expect(cleared.showInboxOnMobile, isTrue);
    });
  });
}
