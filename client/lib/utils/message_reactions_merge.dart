// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/message.dart';
import '../models/reaction_summary.dart';

/// Applica gli aggregati reaction ai messaggi per `logicalMessageId`.
List<ChatMessage> attachReactionsToMessages(
  List<ChatMessage> messages,
  Map<String, List<ReactionSummary>> reactionsByLogicalId,
) {
  if (reactionsByLogicalId.isEmpty) return messages;
  return messages
      .map((message) {
        final lambda = message.logicalMessageId;
        if (lambda == null) return message;
        final reactions = reactionsByLogicalId[lambda];
        if (reactions == null) return message;
        return message.copyWith(reactions: reactions);
      })
      .toList();
}

Map<String, List<ReactionSummary>> indexReactionSummaries(
  List<ReactionSummary> rows, {
  required List<Map<String, dynamic>> rawRows,
}) {
  final grouped = <String, List<ReactionSummary>>{};
  for (var i = 0; i < rawRows.length; i++) {
    final lambda = rawRows[i]['logical_message_id'] as String;
    grouped.putIfAbsent(lambda, () => []).add(rows[i]);
  }
  return grouped;
}

List<String> collectLogicalMessageIds(List<ChatMessage> messages) {
  return messages
      .map((m) => m.logicalMessageId)
      .whereType<String>()
      .toSet()
      .toList();
}
