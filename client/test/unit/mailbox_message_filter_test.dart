// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/mailbox_message_filter.dart';

void main() {
  group('isMailboxPeerMessageRelevant', () {
    const me = 'user-a';
    const peer = 'peer-b';

    test('matches archive_user_id and peer_address', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'archive_user_id': me, 'peer_address': peer},
          currentUserId: me,
          peerAddress: peer,
        ),
        isTrue,
      );
    });

    test('rejects wrong archive_user', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'archive_user_id': 'other', 'peer_address': peer},
          currentUserId: me,
          peerAddress: peer,
        ),
        isFalse,
      );
    });

    test('rejects wrong peer', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'archive_user_id': me, 'peer_address': 'other'},
          currentUserId: me,
          peerAddress: peer,
        ),
        isFalse,
      );
    });
  });

  group('isArchiveUserRow', () {
    test('matches archive_user_id only', () {
      expect(
        isArchiveUserRow(
          record: {'archive_user_id': 'user-a', 'peer_address': 'peer-b'},
          currentUserId: 'user-a',
        ),
        isTrue,
      );
      expect(
        isArchiveUserRow(
          record: {'archive_user_id': 'other'},
          currentUserId: 'user-a',
        ),
        isFalse,
      );
    });
  });
}
