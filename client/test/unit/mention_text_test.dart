// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/mention_text.dart';

void main() {
  group('findMentionMatches', () {
    test('finds single @username', () {
      final matches = findMentionMatches('ciao @mario_rossi!');
      expect(matches.length, 1);
      expect(matches.first.username, 'mario_rossi');
      expect(matches.first.fullText, '@mario_rossi');
    });

    test('ignores email addresses', () {
      expect(findMentionMatches('mario@gmail.com'), isEmpty);
      expect(findMentionMatches('contatta mario@gmail.com'), isEmpty);
    });

    test('ignores short username after @', () {
      expect(findMentionMatches('@ab'), isEmpty);
      expect(findMentionMatches('ciao @ab'), isEmpty);
    });

    test('ignores invalid username characters', () {
      expect(findMentionMatches('@bad-name'), isEmpty);
    });

    test('finds multiple mentions', () {
      final matches = findMentionMatches('@alice e @bob_123');
      expect(matches.length, 2);
      expect(matches[0].username, 'alice');
      expect(matches[1].username, 'bob_123');
    });

    test('case normalizes username', () {
      final matches = findMentionMatches('@Mario_Rossi');
      expect(matches.single.username, 'mario_rossi');
    });
  });

  group('shouldLinkMention', () {
    test('links valid username on peer message', () {
      expect(
        shouldLinkMention(
          username: 'alice',
          isMine: false,
          viewerUsername: 'bob',
        ),
        isTrue,
      );
    });

    test('links other username on own message', () {
      expect(
        shouldLinkMention(
          username: 'alice',
          isMine: true,
          viewerUsername: 'bob',
        ),
        isTrue,
      );
    });

    test('no link on own username in own message', () {
      expect(
        shouldLinkMention(
          username: 'bob',
          isMine: true,
          viewerUsername: 'bob',
        ),
        isFalse,
      );
    });

    test('links own username when message is not mine', () {
      expect(
        shouldLinkMention(
          username: 'bob',
          isMine: false,
          viewerUsername: 'bob',
        ),
        isTrue,
      );
    });
  });
}
