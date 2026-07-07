import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/utils/avatar_color.dart';
import 'package:alfred_client/utils/date_format.dart';
import 'package:alfred_client/utils/duration_format.dart';

void main() {
  group('MessageStatus', () {
    test('maps delivery status strings', () {
      expect(messageStatusFromDelivery('read'), MessageStatus.read);
      expect(messageStatusFromDelivery('delivered'), MessageStatus.delivered);
      expect(messageStatusFromDelivery('pending'), MessageStatus.pending);
      expect(messageStatusFromDelivery(null), MessageStatus.sent);
    });

    test('maps mailbox timestamps for outgoing', () {
      final now = DateTime.now().toUtc();
      expect(
        messageStatusFromMailbox(isMine: true, deliveredAt: null, readAt: null),
        MessageStatus.sent,
      );
      expect(
        messageStatusFromMailbox(isMine: true, deliveredAt: now, readAt: null),
        MessageStatus.delivered,
      );
      expect(
        messageStatusFromMailbox(
          isMine: true,
          deliveredAt: now,
          readAt: now,
        ),
        MessageStatus.read,
      );
      expect(
        messageStatusFromMailbox(isMine: false, deliveredAt: now, readAt: now),
        MessageStatus.sent,
      );
    });

    // spec: MAILBOX-READ-REQ-015
    test('read_at prevails when late delivered_at arrives', () {
      final deliveredLate = DateTime.utc(2026, 6, 29, 12, 5);
      final readEarlier = DateTime.utc(2026, 6, 29, 12, 1);

      expect(
        messageStatusFromMailbox(
          isMine: true,
          deliveredAt: deliveredLate,
          readAt: readEarlier,
        ),
        MessageStatus.read,
      );

      final fromJson = ChatMessage.fromJson(
        json: {
          'id': 'msg-1',
          'created_at': '2026-06-29T12:00:00Z',
          'author_id': 'sender-id',
          'delivered_at': deliveredLate.toIso8601String(),
          'read_at': readEarlier.toIso8601String(),
        },
        currentUserId: 'sender-id',
      );
      expect(fromJson.status, MessageStatus.read);
    });
  });

  group('MessageContentType', () {
    test('maps content type strings', () {
      expect(messageContentTypeFromString('gif'), MessageContentType.gif);
      expect(messageContentTypeFromString('voice'), MessageContentType.voice);
      expect(messageContentTypeFromString('location'), MessageContentType.location);
      expect(messageContentTypeFromString('text'), MessageContentType.text);
      expect(messageContentTypeFromString(null), MessageContentType.text);
    });
  });

  // spec: CONTACTS-REQ-002
  group('ContactProtocol', () {
    test('parses protocol names', () {
      expect(contactProtocolFromString('xmpp'), ContactProtocol.xmpp);
      expect(contactProtocolFromString('internal'), ContactProtocol.internal);
    });
  });

  // spec: PROFILE-REQ-007
  group('ProfileSummary.fromProfilesRow', () {
    test('parses public profile fields', () {
      final summary = ProfileSummary.fromProfilesRow({
        'id': 'u1',
        'username': 'alice',
        'display_name': 'Alice',
        'avatar_url': 'https://example.com/a.jpg',
        'pronouns': 'lei/ella',
      });

      expect(summary.id, 'u1');
      expect(summary.handle, '@alice');
      expect(summary.displayName, 'Alice');
      expect(summary.avatarUrl, 'https://example.com/a.jpg');
      expect(summary.pronouns, 'lei/ella');
    });
  });

  // spec: PROFILE-REQ-012
  group('UserProfile.fromJson', () {
    test('parses pronouns and avatar via summary', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'username': 'alice',
        'display_name': 'Alice',
        'bio': 'Ciao',
        'pronouns': 'lei/ella',
        'avatar_url': 'https://example.com/a.jpg',
        'created_at': '2026-06-28T12:00:00Z',
        'updated_at': '2026-06-28T12:00:00Z',
      });

      expect(profile.summary.pronouns, 'lei/ella');
      expect(profile.summary.avatarUrl, 'https://example.com/a.jpg');
      expect(profile.pronouns, 'lei/ella');
    });
  });

  // spec: PROFILE-REQ-013
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

    test('formats recent days as Italian weekday', () {
      const weekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
      final recent = DateTime.now().subtract(const Duration(days: 3));
      expect(formatMessageTime(recent), weekdays[recent.weekday - 1]);
    });
  });

  group('ChatPeer.fromInboxRow', () {
    test('maps inbox RPC payload', () {
      final at = DateTime.utc(2026, 6, 24, 14, 30);
      final peer = ChatPeer.fromInboxRow({
        'protocol': 'internal',
        'display_name': 'Alice',
        'last_message_preview': 'Ciao!',
        'last_message_at': at.toIso8601String(),
        'unread_count': 2,
        'peer_profile_id': 'peer-1',
        'peer_avatar_url': 'https://example.com/a.jpg',
        'peer_pronouns': 'lei/ella',
        'peer_profile_kind': 'group',
      });

      expect(peer.profileId, 'peer-1');
      expect(peer.profile.displayName, 'Alice');
      expect(peer.displayName, 'Alice');
      expect(peer.preview, 'Ciao!');
      expect(peer.unreadCount, 2);
      expect(peer.protocol, 'internal');
      expect(peer.lastMessageAt, at);
      expect(peer.profile.avatarUrl, 'https://example.com/a.jpg');
      expect(peer.profile.pronouns, 'lei/ella');
      expect(peer.isGroup, isTrue);
    });
  });

  group('ChatMessage.fromJson', () {
    test('detects mine vs theirs from author_id', () {
      final message = ChatMessage.fromJson(
        json: {
          'id': '1',
          'body': 'ciao',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'user-a',
          'delivered_at': null,
          'read_at': null,
        },
        currentUserId: 'user-a',
      );
      expect(message.isMine, isTrue);
      expect(message.status, MessageStatus.sent);

      final incoming = ChatMessage.fromJson(
        json: {
          'id': '2',
          'body': 'risposta',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'user-b',
        },
        currentUserId: 'user-a',
      );
      expect(incoming.isMine, isFalse);

      final delivered = ChatMessage.fromJson(
        json: {
          'id': '3',
          'body': 'out',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'user-a',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        },
        currentUserId: 'user-a',
      );
      expect(delivered.status, MessageStatus.delivered);
    });

    test('parses gif messages', () {
      final gif = ChatMessage.fromJson(
        json: {
          'id': '3',
          'body': '',
          'content_type': 'gif',
          'media_url': 'https://example.com/fun.gif',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'user-b',
        },
        currentUserId: 'user-a',
      );
      expect(gif.isGif, isTrue);
      expect(gif.hasRenderableContent, isTrue);
    });

    test('parses voice messages', () {
      final voice = ChatMessage.fromJson(
        json: {
          'id': '4',
          'body': '',
          'content_type': 'voice',
          'media_url': 'https://example.com/note.webm',
          'duration_seconds': 42,
          'media_mime': 'audio/webm',
          'media_size_bytes': 12000,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'user-b',
        },
        currentUserId: 'user-a',
      );
      expect(voice.isVoice, isTrue);
      expect(voice.durationSeconds, 42);
      expect(voice.hasRenderableContent, isTrue);
    });
  });

  group('formatVoiceDuration', () {
    test('formats mm:ss', () {
      expect(formatVoiceDuration(42), '0:42');
      expect(formatVoiceDuration(125), '2:05');
    });
  });
}
