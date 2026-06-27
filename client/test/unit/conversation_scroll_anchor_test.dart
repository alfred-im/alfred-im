import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/conversation_scroll_anchor.dart';

void main() {
  group('ConversationScrollAnchor', () {
    test('isAttached when pixels within threshold', () {
      expect(ConversationScrollAnchor.isAttached(0), isTrue);
      expect(ConversationScrollAnchor.isAttached(48), isTrue);
      expect(ConversationScrollAnchor.isAttached(49), isFalse);
    });

    test('shouldAutoScrollOnAppend when attached', () {
      expect(
        ConversationScrollAnchor.shouldAutoScrollOnAppend(
          wasAttached: true,
          hasOutgoingInBatch: false,
        ),
        isTrue,
      );
    });

    test('shouldAutoScrollOnAppend when outgoing while detached', () {
      expect(
        ConversationScrollAnchor.shouldAutoScrollOnAppend(
          wasAttached: false,
          hasOutgoingInBatch: true,
        ),
        isTrue,
      );
    });

    test('should not auto scroll when detached and only incoming', () {
      expect(
        ConversationScrollAnchor.shouldAutoScrollOnAppend(
          wasAttached: false,
          hasOutgoingInBatch: false,
        ),
        isFalse,
      );
    });
  });
}
