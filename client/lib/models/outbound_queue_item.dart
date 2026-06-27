import 'dart:convert';

enum OutboundContentKind { text, gif, voice }

OutboundContentKind outboundContentKindFromString(String value) {
  switch (value) {
    case 'gif':
      return OutboundContentKind.gif;
    case 'voice':
      return OutboundContentKind.voice;
    default:
      return OutboundContentKind.text;
  }
}

/// Persisted outbound payload for retry after network/upload failures.
class OutboundQueueItem {
  const OutboundQueueItem({
    required this.clientId,
    required this.conversationId,
    required this.kind,
    required this.attempts,
    required this.queuedAt,
    this.body,
    this.localMediaPath,
    this.durationSeconds,
    this.mediaMime,
    this.lastError,
  });

  final String clientId;
  final String conversationId;
  final OutboundContentKind kind;
  final int attempts;
  final DateTime queuedAt;
  final String? body;
  final String? localMediaPath;
  final int? durationSeconds;
  final String? mediaMime;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'conversationId': conversationId,
        'kind': kind.name,
        'attempts': attempts,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'body': body,
        'localMediaPath': localMediaPath,
        'durationSeconds': durationSeconds,
        'mediaMime': mediaMime,
        'lastError': lastError,
      };

  factory OutboundQueueItem.fromJson(Map<String, dynamic> json) {
    return OutboundQueueItem(
      clientId: json['clientId'] as String,
      conversationId: json['conversationId'] as String,
      kind: outboundContentKindFromString(json['kind'] as String? ?? 'text'),
      attempts: json['attempts'] as int? ?? 0,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      body: json['body'] as String?,
      localMediaPath: json['localMediaPath'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      mediaMime: json['mediaMime'] as String?,
      lastError: json['lastError'] as String?,
    );
  }

  OutboundQueueItem copyWith({
    int? attempts,
    String? lastError,
  }) {
    return OutboundQueueItem(
      clientId: clientId,
      conversationId: conversationId,
      kind: kind,
      attempts: attempts ?? this.attempts,
      queuedAt: queuedAt,
      body: body,
      localMediaPath: localMediaPath,
      durationSeconds: durationSeconds,
      mediaMime: mediaMime,
      lastError: lastError ?? this.lastError,
    );
  }

  static List<OutboundQueueItem> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OutboundQueueItem.fromJson)
        .toList();
  }

  static String encodeList(List<OutboundQueueItem> items) {
    return jsonEncode(items.map((item) => item.toJson()).toList());
  }
}
