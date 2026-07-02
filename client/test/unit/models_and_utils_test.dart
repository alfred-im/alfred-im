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

  group('ContactProtocol', () {
    test('parses protocol names', () {
      expect(contactProtocolFromString('xmpp'), ContactProtocol.xmpp);
      expect(contactProtocolFromString('internal'), ContactProtocol.internal);
    });
  });

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

    test('parses gif messages', () {
      final gif = ChatMessage.fromJson(
        json: {
          'id': '3',
          'body': '',
          'content_type': 'gif',
          'media_url': 'https://example.com/fun.gif',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'sender_id': 'user-b',
          'delivery_status': 'sent',
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
          'sender_id': 'user-b',
          'delivery_status': 'sent',
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
