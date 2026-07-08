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
    case MessageContentType.text:
      return message.body;
  }
}
