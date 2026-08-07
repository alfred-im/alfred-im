// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/reaction_summary.dart';
import '../theme/alfred_colors.dart';

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.reactions,
    this.onReactionTap,
  });

  final List<ReactionSummary> reactions;
  final void Function(ReactionSummary reaction)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final reaction in reactions)
            ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              backgroundColor: reaction.includesMe
                  ? AlfredColors.bubbleOutgoing.withValues(alpha: 0.35)
                  : AlfredColors.panel,
              side: BorderSide(
                color: reaction.includesMe
                    ? AlfredColors.accentBlue
                    : AlfredColors.border,
              ),
              label: Text(
                '${reaction.emoji} ${reaction.count}',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed:
                  onReactionTap == null ? null : () => onReactionTap!(reaction),
            ),
        ],
      ),
    );
  }
}
