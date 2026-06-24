enum MessageStatus { sent, delivered, read, pending, failed }

MessageStatus messageStatusFromDelivery(String? value) {
  switch (value) {
    case 'delivered':
      return MessageStatus.delivered;
    case 'read':
      return MessageStatus.read;
    case 'pending':
      return MessageStatus.pending;
    case 'failed':
      return MessageStatus.failed;
    default:
      return MessageStatus.sent;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.timeLabel,
    required this.isMine,
    this.status = MessageStatus.sent,
    this.createdAt,
    this.senderId,
  });

  final String id;
  final String body;
  final String timeLabel;
  final bool isMine;
  final MessageStatus status;
  final DateTime? createdAt;
  final String? senderId;

  factory ChatMessage.fromJson({
    required Map<String, dynamic> json,
    required String currentUserId,
  }) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String,
      timeLabel: '', // filled by UI via formatMessageTime
      isMine: json['sender_id'] == currentUserId,
      status: messageStatusFromDelivery(json['delivery_status'] as String?),
      createdAt: createdAt,
      senderId: json['sender_id'] as String?,
    );
  }
}
