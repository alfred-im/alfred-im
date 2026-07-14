// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

enum MessageStatus { sent, delivered, read, pending, failed }

enum MessageContentType { text, gif, voice, location, image, video }

/// Parses ISO8601 timestamps from PostgREST (nullable).
DateTime? _parseOptionalTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isEmpty) return null;
  return DateTime.parse(value as String);
}

/// Maps mailbox archive timestamps to [MessageStatus] for outgoing bubbles.
MessageStatus messageStatusFromMailbox({
  required bool isMine,
  DateTime? deliveredAt,
  DateTime? readAt,
  DateTime? failedAt,
}) {
  if (!isMine) return MessageStatus.sent;
  if (failedAt != null) return MessageStatus.failed;
  if (readAt != null) return MessageStatus.read;
  if (deliveredAt != null) return MessageStatus.delivered;
  return MessageStatus.sent;
}

/// Legacy helper — kept for tests that still pass delivery_status strings.
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
    case 'location':
      return MessageContentType.location;
    case 'image':
      return MessageContentType.image;
    case 'video':
      return MessageContentType.video;
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
    this.clientMessageId,
    String? authorId,
    String? senderId,
    this.originalAuthorId,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorProfileId,
    this.contentType = MessageContentType.text,
    this.mediaUrl,
    this.durationSeconds,
    this.mediaMime,
    this.mediaSizeBytes,
    this.latitude,
    this.longitude,
    this.retryPayloadPath,
    this.deliveredAt,
    this.readAt,
    this.failedAt,
  }) : authorId = authorId ?? senderId;

  final String id;
  final String body;
  final String timeLabel;
  final bool isMine;
  final MessageStatus status;
  final DateTime? createdAt;
  /// Idempotency key from client send; matches optimistic bubble [id] before server row exists.
  final String? clientMessageId;
  final String? authorId;
  final String? originalAuthorId;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String? authorProfileId;
  final MessageContentType contentType;
  final String? mediaUrl;
  final int? durationSeconds;
  final String? mediaMime;
  final int? mediaSizeBytes;
  final double? latitude;
  final double? longitude;
  final String? retryPayloadPath;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? failedAt;

  /// Chi ha scritto il contenuto — campo canonico (sempre valorizzato nei flussi gruppo).
  String? get contentAuthorId => originalAuthorId;

  /// Etichetta autore in UI; fallback `author_id` solo per chat private legacy.
  String? get displayAuthorId => originalAuthorId ?? authorId;

  /// Back-compat for code that still reads [senderId].
  String? get senderId => authorId;

  bool get isGif =>
      contentType == MessageContentType.gif &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isVoice =>
      contentType == MessageContentType.voice &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isLocation =>
      contentType == MessageContentType.location &&
      latitude != null &&
      longitude != null;

  bool get isImage =>
      contentType == MessageContentType.image &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isVideo =>
      contentType == MessageContentType.video &&
      mediaUrl != null &&
      mediaUrl!.isNotEmpty;

  bool get isMedia => isGif || isVoice || isLocation || isImage || isVideo;

  bool get hasRenderableContent =>
      body.isNotEmpty || isGif || isVoice || isLocation || isImage || isVideo;

  bool get canRetry => isMine && status == MessageStatus.failed;

  factory ChatMessage.fromJson({
    required Map<String, dynamic> json,
    required String currentUserId,
  }) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final authorId =
        json['author_id'] as String? ?? json['sender_id'] as String?;
    final originalAuthorId = json['original_author_id'] as String?;
    final isMine =
        authorId == currentUserId || originalAuthorId == currentUserId;
    final deliveredAt = _parseOptionalTimestamp(json['delivered_at']);
    final readAt = _parseOptionalTimestamp(json['read_at']);
    final failedAt = _parseOptionalTimestamp(json['failed_at']);

    final status = json.containsKey('delivery_status') &&
            !json.containsKey('delivered_at') &&
            !json.containsKey('read_at') &&
            !json.containsKey('failed_at')
        ? messageStatusFromDelivery(json['delivery_status'] as String?)
        : messageStatusFromMailbox(
            isMine: isMine,
            deliveredAt: deliveredAt,
            readAt: readAt,
            failedAt: failedAt,
          );

    final clientMessageId = json['client_message_id'] as String?;

    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      timeLabel: '',
      isMine: isMine,
      status: status,
      createdAt: createdAt,
      clientMessageId: clientMessageId,
      authorId: authorId,
      originalAuthorId: originalAuthorId,
      contentType: messageContentTypeFromString(json['content_type'] as String?),
      mediaUrl: json['media_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      mediaMime: json['media_mime'] as String?,
      mediaSizeBytes: json['media_size_bytes'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      deliveredAt: deliveredAt,
      readAt: readAt,
      failedAt: failedAt,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? body,
    String? timeLabel,
    bool? isMine,
    MessageStatus? status,
    DateTime? createdAt,
    String? clientMessageId,
    String? authorId,
    String? originalAuthorId,
    String? authorDisplayName,
    String? authorAvatarUrl,
    String? authorProfileId,
    bool clearAuthorAvatarUrl = false,
    MessageContentType? contentType,
    String? mediaUrl,
    int? durationSeconds,
    String? mediaMime,
    int? mediaSizeBytes,
    double? latitude,
    double? longitude,
    String? retryPayloadPath,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? failedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      body: body ?? this.body,
      timeLabel: timeLabel ?? this.timeLabel,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      authorId: authorId ?? this.authorId,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      authorAvatarUrl:
          clearAuthorAvatarUrl ? null : authorAvatarUrl ?? this.authorAvatarUrl,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      contentType: contentType ?? this.contentType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mediaMime: mediaMime ?? this.mediaMime,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      retryPayloadPath: retryPayloadPath ?? this.retryPayloadPath,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      failedAt: failedAt ?? this.failedAt,
    );
  }
}
