enum MessageStatus { sent, delivered, read, pending, failed }

enum MessageContentType { text, gif, voice }

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

MessageContentType messageContentTypeFromString(String? value) {
  switch (value) {
    case 'gif':
      return MessageContentType.gif;
    case 'voice':
      return MessageContentType.voice;
    default:
      return MessageContentType.text;
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
    this.contentType = MessageContentType.text,
    this.mediaUrl,
    this.durationSeconds,
    this.mediaMime,
    this.mediaSizeBytes,
    this.retryPayloadPath,
  });

  final String id;
  final String body;
  final String timeLabel;
  final bool isMine;
  final MessageStatus status;
  final DateTime? createdAt;
  final String? senderId;
  final MessageContentType contentType;
  final String? mediaUrl;
  final int? durationSeconds;
  final String? mediaMime;
  final int? mediaSizeBytes;
  final String? retryPayloadPath;

  bool get isGif =>
      contentType == MessageContentType.gif &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isVoice =>
      contentType == MessageContentType.voice &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isMedia => isGif || isVoice;

  bool get hasRenderableContent => body.isNotEmpty || isGif || isVoice;

  bool get canRetry => isMine && status == MessageStatus.failed;

  factory ChatMessage.fromJson({
    required Map<String, dynamic> json,
    required String currentUserId,
  }) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      timeLabel: '',
      isMine: json['sender_id'] == currentUserId,
      status: messageStatusFromDelivery(json['delivery_status'] as String?),
      createdAt: createdAt,
      senderId: json['sender_id'] as String?,
      contentType: messageContentTypeFromString(json['content_type'] as String?),
      mediaUrl: json['media_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      mediaMime: json['media_mime'] as String?,
      mediaSizeBytes: json['media_size_bytes'] as int?,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? body,
    String? timeLabel,
    bool? isMine,
    MessageStatus? status,
    DateTime? createdAt,
    String? senderId,
    MessageContentType? contentType,
    String? mediaUrl,
    int? durationSeconds,
    String? mediaMime,
    int? mediaSizeBytes,
    String? retryPayloadPath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      body: body ?? this.body,
      timeLabel: timeLabel ?? this.timeLabel,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      senderId: senderId ?? this.senderId,
      contentType: contentType ?? this.contentType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mediaMime: mediaMime ?? this.mediaMime,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      retryPayloadPath: retryPayloadPath ?? this.retryPayloadPath,
    );
  }
}
