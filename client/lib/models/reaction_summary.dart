// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Aggregato derivato per la bolla — da `list_message_reactions`.
class ReactionSummary {
  const ReactionSummary({
    required this.emoji,
    required this.count,
    required this.includesMe,
  });

  final String emoji;
  final int count;
  final bool includesMe;

  factory ReactionSummary.fromJson(Map<String, dynamic> json) {
    return ReactionSummary(
      emoji: json['emoji'] as String,
      count: (json['reaction_count'] as num).toInt(),
      includesMe: json['includes_me'] as bool? ?? false,
    );
  }
}
