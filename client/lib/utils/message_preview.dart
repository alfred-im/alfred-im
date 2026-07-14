// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/message.dart';

/// Anteprima inbox per tipo messaggio — allineata a SURF-CHAT-008.
String inboxPreviewForMessage(ChatMessage message) {
  switch (message.contentType) {
    case MessageContentType.gif:
      return '[GIF]';
    case MessageContentType.voice:
      return '🎤';
    case MessageContentType.location:
      return '📍 Posizione';
    case MessageContentType.image:
      return message.body.isNotEmpty ? '📷 ${message.body}' : '📷 Foto';
    case MessageContentType.video:
      return message.body.isNotEmpty ? '🎬 ${message.body}' : '🎬 Video';
    case MessageContentType.text:
      return message.body;
  }
}
