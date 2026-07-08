import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/utils/author_display.dart';

// spec: PROM-GROUP-AUTHOR-DISPLAY-001
void main() {
  group('ChatMessage contentAuthorId', () {
    test('content author is original_author_id', () {
      const message = ChatMessage(
        id: '1',
        body: 'ciao gruppo',
        timeLabel: '12:00',
        isMine: false,
        authorId: 'group-1',
        originalAuthorId: 'human-1',
      );

      expect(message.contentAuthorId, 'human-1');
      expect(message.displayAuthorId, 'human-1');
    });

    test('group broadcast uses group as content author', () {
      const message = ChatMessage(
        id: '2',
        body: 'broadcast',
        timeLabel: '12:00',
        isMine: true,
        authorId: 'group-1',
        originalAuthorId: 'group-1',
      );

      expect(message.contentAuthorId, 'group-1');
      expect(message.displayAuthorId, 'group-1');
    });

    test('displayAuthorId falls back to author_id for legacy private chat', () {
      const message = ChatMessage(
        id: '3',
        body: 'privato',
        timeLabel: '12:00',
        isMine: true,
        authorId: 'user-a',
      );

      expect(message.contentAuthorId, isNull);
      expect(message.displayAuthorId, 'user-a');
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
      expect(message.contentAuthorId, 'user-a');
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
      expect(message.contentAuthorId, 'user-b');
    });

    test('group broadcast row is mine for group account', () {
      final message = ChatMessage.fromJson(
        json: {
          'id': '5',
          'body': 'annuncio',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'author_id': 'group-1',
          'original_author_id': 'group-1',
        },
        currentUserId: 'group-1',
      );

      expect(message.isMine, isTrue);
      expect(message.contentAuthorId, 'group-1');
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

  group('author display', () {
    test('authorLabelForProfile prefers display name over username', () {
      const profile = ProfileSummary(
        id: 'u1',
        displayName: 'Marco Rossi',
        username: 'marco',
      );

      expect(authorLabelForProfile(profile), 'Marco Rossi');
    });

    test('authorLabelForProfile falls back to username without @', () {
      const profile = ProfileSummary(
        id: 'u2',
        displayName: '',
        username: 'marco',
      );

      expect(authorLabelForProfile(profile), 'marco');
    });

    test('enrichMessageAuthor sets avatar and readable name', () {
      const message = ChatMessage(
        id: '1',
        body: 'ciao',
        timeLabel: '12:00',
        isMine: false,
        authorId: 'group-1',
        originalAuthorId: 'human-1',
      );
      const profile = ProfileSummary(
        id: 'human-1',
        displayName: 'Giulia',
        username: 'giulia',
        avatarUrl: 'https://example.com/a.png',
      );

      final enriched = enrichMessageAuthor(
        message: message,
        profilesById: {'human-1': profile},
        currentUserId: 'me',
      );

      expect(enriched.authorDisplayName, 'Giulia');
      expect(enriched.authorAvatarUrl, 'https://example.com/a.png');
      expect(enriched.authorProfileId, 'human-1');
    });

    test('enrichMessageAuthor labels own messages as Tu', () {
      const message = ChatMessage(
        id: '2',
        body: 'mio',
        timeLabel: '12:01',
        isMine: true,
        authorId: 'group-1',
        originalAuthorId: 'me',
      );

      final enriched = enrichMessageAuthor(
        message: message,
        profilesById: const {},
        currentUserId: 'me',
      );

      expect(enriched.authorDisplayName, 'Tu');
    });
  });
}
