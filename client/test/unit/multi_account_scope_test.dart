import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/providers/messages_controller.dart';

void main() {
  group('Multi-account scope', () {
    test('outboundQueueKey includes userId and peerProfileId', () {
      const userA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      const userB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
      const peer = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

      final keyA = MessagesController.outboundQueueKey(
        userId: userA,
        peerProfileId: peer,
      );
      final keyB = MessagesController.outboundQueueKey(
        userId: userB,
        peerProfileId: peer,
      );

      expect(keyA, isNot(keyB));
      expect(keyA, '$userA|$peer');
      expect(keyB, '$userB|$peer');
    });
  });
}
