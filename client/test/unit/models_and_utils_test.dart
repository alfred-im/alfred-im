import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/models/conversation.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/utils/avatar_color.dart';
import 'package:alfred_client/utils/date_format.dart';

void main() {
  group('MessageStatus', () {
    test('maps delivery status strings', () {
      expect(messageStatusFromDelivery('read'), MessageStatus.read);
      expect(messageStatusFromDelivery('delivered'), MessageStatus.delivered);
      expect(messageStatusFromDelivery('pending'), MessageStatus.pending);
      expect(messageStatusFromDelivery(null), MessageStatus.sent);
    });
  });

  group('ContactProtocol', () {
    test('parses protocol names', () {
      expect(contactProtocolFromString('xmpp'), ContactProtocol.xmpp);
      expect(contactProtocolFromString('internal'), ContactProtocol.internal);
    });
  });

  group('avatarColorForId', () {
    test('is deterministic', () {
      expect(avatarColorForId('abc'), avatarColorForId('abc'));
      expect(avatarColorForId('abc'), isNot(avatarColorForId('xyz')));
    });
  });

  group('formatMessageTime', () {
    test('formats today as hour:minute', () {
      final now = DateTime.now();
      final label = formatMessageTime(now);
      expect(label, isNotEmpty);
    });
  });

  group('Conversation.fromListRpcRow', () {
    test('maps inbox RPC payload', () {
      final at = DateTime.utc(2026, 6, 24, 14, 30);
      final conversation = Conversation.fromListRpcRow({
        'conversation_id': 'conv-1',
        'protocol': 'internal',
        'display_name': 'Alice',
        'last_message_preview': 'Ciao!',
        'last_message_at': at.toIso8601String(),
        'unread_count': 2,
      });

      expect(conversation.id, 'conv-1');
      expect(conversation.name, 'Alice');
      expect(conversation.preview, 'Ciao!');
      expect(conversation.unreadCount, 2);
      expect(conversation.protocol, 'internal');
      expect(conversation.lastMessageAt, at);
    });
  });

  group('ChatMessage.fromJson', () {
    test('detects mine vs theirs', () {
      final message = ChatMessage.fromJson(
        json: {
          'id': '1',
          'body': 'ciao',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sender_id': 'user-a',
          'delivery_status': 'sent',
        },
        currentUserId: 'user-a',
      );
      expect(message.isMine, isTrue);

      final incoming = ChatMessage.fromJson(
        json: {
          'id': '2',
          'body': 'risposta',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sender_id': 'user-b',
          'delivery_status': 'read',
        },
        currentUserId: 'user-a',
      );
      expect(incoming.isMine, isFalse);
      expect(incoming.status, MessageStatus.read);
    });
  });
}
