import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';

// spec: GROUP-DELIVERY-REQ-009
void main() {
  group('ChatMessage displayAuthorId', () {
    test('prefers original_author_id over author_id', () {
      const message = ChatMessage(
        id: '1',
        body: 'ciao gruppo',
        timeLabel: '12:00',
        isMine: false,
        authorId: 'group-1',
        originalAuthorId: 'human-1',
      );

      expect(message.displayAuthorId, 'human-1');
    });

    test('falls back to author_id when original is null', () {
      const message = ChatMessage(
        id: '2',
        body: 'broadcast',
        timeLabel: '12:00',
        isMine: false,
        authorId: 'group-1',
      );

      expect(message.displayAuthorId, 'group-1');
    });
  });

  group('ChatMessage.fromJson group erogation', () {
    test('marks mine when original_author is current user', () {
      final message = ChatMessage.fromJson(
        json: {
          'id': '3',
          'body': 'via gruppo',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'group-1',
          'original_author_id': 'user-a',
        },
        currentUserId: 'user-a',
      );

      expect(message.isMine, isTrue);
      expect(message.displayAuthorId, 'user-a');
    });

    test('incoming erogated message is not mine', () {
      final message = ChatMessage.fromJson(
        json: {
          'id': '4',
          'body': 'altro membro',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'group-1',
          'original_author_id': 'user-b',
        },
        currentUserId: 'user-a',
      );

      expect(message.isMine, isFalse);
      expect(message.displayAuthorId, 'user-b');
    });
  });

  group('ProfileKind', () {
    test('parses group from wire value', () {
      expect(ProfileKind.fromString('group'), ProfileKind.group);
      expect(ProfileKind.fromString('user'), ProfileKind.user);
      expect(ProfileKind.fromString(null), ProfileKind.user);
    });

    test('isGroup on ProfileSummary', () {
      const group = ProfileSummary(
        id: 'g1',
        displayName: 'Famiglia',
        profileKind: ProfileKind.group,
      );
      expect(group.isGroup, isTrue);
    });
  });
}
