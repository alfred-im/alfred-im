// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/reaction_summary.dart';
import 'package:alfred_client/utils/message_reactions_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attachReactionsToMessages', () {
    test('merges summaries by logicalMessageId', () {
      const lambda = '11111111-1111-1111-1111-111111111111';
      final messages = [
        ChatMessage(
          id: 'row-1',
          body: 'ciao',
          timeLabel: '12:00',
          isMine: true,
          logicalMessageId: lambda,
        ),
      ];
      final merged = attachReactionsToMessages(messages, {
        lambda: const [
          ReactionSummary(emoji: '\u{2764}', count: 2, includesMe: true),
        ],
      });
      expect(merged.single.reactions, hasLength(1));
      expect(merged.single.reactions.single.emoji, '\u{2764}');
    });

    test('skips messages without lambda', () {
      final messages = [
        ChatMessage(
          id: 'pending',
          body: 'pending',
          timeLabel: '',
          isMine: true,
        ),
      ];
      final merged = attachReactionsToMessages(messages, {
        'other': const [
          ReactionSummary(emoji: '\u{1F600}', count: 1, includesMe: false),
        ],
      });
      expect(merged.single.reactions, isEmpty);
    });
  });

  group('shouldWithdrawReactionOnTap', () {
    test('withdraws when emoji is mine even if count is shared', () {
      const reactions = [
        ReactionSummary(emoji: '\u{1F600}', count: 2, includesMe: true),
        ReactionSummary(emoji: '\u{2764}', count: 1, includesMe: false),
      ];
      expect(
        shouldWithdrawReactionOnTap(reactions: reactions, emoji: '\u{1F600}'),
        isTrue,
      );
    });

    test('applies when emoji is only from others', () {
      const reactions = [
        ReactionSummary(emoji: '\u{1F600}', count: 2, includesMe: false),
      ];
      expect(
        shouldWithdrawReactionOnTap(reactions: reactions, emoji: '\u{1F600}'),
        isFalse,
      );
    });

    test('withdraws solo reaction', () {
      const reactions = [
        ReactionSummary(emoji: '\u{1F600}', count: 1, includesMe: true),
      ];
      expect(
        shouldWithdrawReactionOnTap(reactions: reactions, emoji: '\u{1F600}'),
        isTrue,
      );
    });
  });
}
