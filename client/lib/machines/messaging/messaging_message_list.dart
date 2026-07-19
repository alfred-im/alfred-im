// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/message.dart';
import '../../utils/date_format.dart';
import '../../utils/merge_chat_message.dart';

int indexForMessage(List<ChatMessage> list, ChatMessage message) {
  final clientKey = message.clientMessageId;
  for (var i = 0; i < list.length; i++) {
    final existing = list[i];
    if (existing.id == message.id) return i;
    if (clientKey != null && (existing.id == clientKey || existing.clientMessageId == clientKey)) return i;
    final existingClientKey = existing.clientMessageId;
    if (existingClientKey != null && existingClientKey == message.id) return i;
  }
  return -1;
}

List<ChatMessage> replaceOrInsertMessage(List<ChatMessage> list, ChatMessage message) {
  final index = indexForMessage(list, message);
  if (index >= 0) {
    final next = List<ChatMessage>.from(list);
    next[index] = mergeChatMessage(existing: list[index], incoming: message);
    return next;
  }
  return [...list, message];
}

List<ChatMessage> dedupeMessages(List<ChatMessage> source) {
  final deduped = <ChatMessage>[];
  for (final message in source) {
    final index = indexForMessage(deduped, message);
    if (index >= 0) {
      deduped[index] = mergeChatMessage(existing: deduped[index], incoming: message);
    } else {
      deduped.add(message);
    }
  }
  return deduped;
}

List<ChatMessage> prependOlderMessages({
  required List<ChatMessage> existing,
  required List<ChatMessage> older,
}) {
  if (older.isEmpty) return existing;
  return dedupeMessages([...older, ...existing]);
}

ChatMessage withTimeLabel(ChatMessage message) {
  final at = message.createdAt ?? DateTime.now();
  return message.copyWith(timeLabel: formatMessageTime(at), createdAt: at);
}
