enum MessageStatus { sent, delivered, read }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.timeLabel,
    required this.isMine,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String body;
  final String timeLabel;
  final bool isMine;
  final MessageStatus status;
}
