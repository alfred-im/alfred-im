// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/reaction_summary.dart';
import '../theme/alfred_colors.dart';

/// Reaction aggregate sulla bolla — pillola compatta sul bordo inferiore.
class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.reactions,
    this.onReactionTap,
    this.compact = false,
  });

  final List<ReactionSummary> reactions;
  final void Function(ReactionSummary reaction)? onReactionTap;
  /// Su [MessageBubble] le reaction sono in overlay; padding ridotto.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      elevation: compact ? 1.5 : 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 6,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: AlfredColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AlfredColors.border),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < reactions.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              _ReactionChip(
                reaction: reactions[i],
                onTap: onReactionTap == null
                    ? null
                    : () => onReactionTap!(reactions[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    this.onTap,
  });

  final ReactionSummary reaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: reaction.includesMe
          ? BoxDecoration(
              color: AlfredColors.bubbleOutgoing.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AlfredColors.accentBlue.withValues(alpha: 0.65),
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reaction.emoji, style: const TextStyle(fontSize: 15, height: 1.1)),
          if (reaction.count > 1) ...[
            const SizedBox(width: 2),
            Text(
              '${reaction.count}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AlfredColors.textSecondary,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}
