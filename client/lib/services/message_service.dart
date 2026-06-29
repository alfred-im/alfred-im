import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/voice_config.dart';
import '../models/message.dart';

class MessageService {
  MessageService(this._client);

  final SupabaseClient _client;

  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
  }) async {
    final rows = await _client.rpc(
      'list_peer_messages',
      params: {
        'p_peer_profile_id': peerProfileId,
        'p_limit': limit,
      },
    );

    return (rows as List<dynamic>)
        .map(
          (r) => ChatMessage.fromJson(
            json: r as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .where((m) => m.hasRenderableContent)
        .toList();
  }

  Future<ChatMessage> sendToProfile({
    required String recipientProfileId,
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToProfile(
      recipientProfileId: recipientProfileId,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'text',
      body: body,
    );
  }

  Future<ChatMessage> sendGifToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToProfile(
      recipientProfileId: recipientProfileId,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'gif',
      body: '',
      mediaUrl: mediaUrl,
    );
  }

  Future<ChatMessage> sendVoiceToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToProfile(
      recipientProfileId: recipientProfileId,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'voice',
      body: '',
      mediaUrl: mediaUrl,
      durationSeconds: durationSeconds,
      mediaMime: VoiceConfig.canonicalMime,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  Future<ChatMessage> _sendToProfile({
    required String recipientProfileId,
    required String currentUserId,
    required String clientMessageId,
    required String contentType,
    required String body,
    String? mediaUrl,
    int? durationSeconds,
    String? mediaMime,
    int? mediaSizeBytes,
  }) async {
    if (contentType == 'text') {
      final row = await _client.rpc(
        'send_message_to_profile',
        params: {
          'p_recipient_profile_id': recipientProfileId,
          'p_body': body,
          'p_client_message_id': clientMessageId,
          'p_content_type': contentType,
        },
      );
      return ChatMessage.fromJson(
        json: row as Map<String, dynamic>,
        currentUserId: currentUserId,
      );
    }

    final params = {
      'p_recipient_profile_id': recipientProfileId,
      'p_body': body,
      'p_client_message_id': clientMessageId,
      'p_content_type': contentType,
      'p_media_url': ?mediaUrl,
      'p_duration_seconds': ?durationSeconds,
      'p_media_mime': ?mediaMime,
      'p_media_size_bytes': ?mediaSizeBytes,
    };

    final row = await _client.rpc('send_message_to_profile', params: params);

    return ChatMessage.fromJson(
      json: row as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }

  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerProfileId,
    required void Function(ChatMessage message) onMessage,
  }) {
    bool isRelevant(Map<String, dynamic> record) {
      final sender = record['sender_id'] as String?;
      final recipient = record['recipient_profile_id'] as String?;
      return (sender == currentUserId && recipient == peerProfileId) ||
          (sender == peerProfileId && recipient == currentUserId);
    }

    void handle(PostgresChangePayload payload) {
      final record = payload.newRecord;
      if (record.isEmpty || !isRelevant(record)) return;
      final message = ChatMessage.fromJson(
        json: record,
        currentUserId: currentUserId,
      );
      if (!message.hasRenderableContent) return;
      onMessage(message);
    }

    return _client
        .channel('messages-peer-$currentUserId-$peerProfileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: handle,
        )
        .subscribe();
  }

  void disposeChannel(RealtimeChannel? channel) {
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }
}
