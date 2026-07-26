// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/mailbox_message_filter.dart';

void main() {
  group('isMailboxPeerMessageRelevant', () {
    const me = 'user-a';
    const peer = 'peer-b';

    test('matches owner_id and peer_profile_id', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'owner_id': me, 'peer_profile_id': peer},
          currentUserId: me,
          peerProfileId: peer,
        ),
        isTrue,
      );
    });

    test('rejects wrong owner', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'owner_id': 'other', 'peer_profile_id': peer},
          currentUserId: me,
          peerProfileId: peer,
        ),
        isFalse,
      );
    });

    test('rejects wrong peer', () {
      expect(
        isMailboxPeerMessageRelevant(
          record: {'owner_id': me, 'peer_profile_id': 'other'},
          currentUserId: me,
          peerProfileId: peer,
        ),
        isFalse,
      );
    });
  });

  group('isOwnerArchiveRow', () {
    test('matches owner_id only', () {
      expect(
        isOwnerArchiveRow(
          record: {'owner_id': 'user-a', 'peer_profile_id': 'peer-b'},
          currentUserId: 'user-a',
        ),
        isTrue,
      );
      expect(
        isOwnerArchiveRow(
          record: {'owner_id': 'other'},
          currentUserId: 'user-a',
        ),
        isFalse,
      );
    });
  });
}
