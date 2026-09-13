// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/voice_config.dart';
import '../models/message.dart';
import '../models/reaction_summary.dart';
import '../utils/mailbox_message_filter.dart';

/// RPC e realtime messaggi 1:1 verso un indirizzo peer.
class PeerMessageService {
  PeerMessageService(this._client);

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerAddress,
    required String currentUserId,
    int limit = 100,
    DateTime? beforeCreatedAt,
  }) async {
    final params = <String, dynamic>{
      'p_peer_address': peerAddress.trim().toLowerCase(),
      'p_limit': limit,
    };
    if (beforeCreatedAt != null) {
      params['p_before_created_at'] = beforeCreatedAt.toUtc().toIso8601String();
    }

    final rows = await _client.rpc(
      'list_peer_messages',
      params: params,
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

  Future<Map<String, List<ReactionSummary>>> fetchReactionSummaries(
    List<String> logicalMessageIds,
  ) async {
    if (logicalMessageIds.isEmpty) return {};
    final rows = await _client.rpc(
      'list_message_reactions',
      params: {'p_logical_message_ids': logicalMessageIds},
    );
    final rawRows = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    final grouped = <String, List<ReactionSummary>>{};
    for (final row in rawRows) {
      final lambda = row['logical_message_id'] as String;
      grouped
          .putIfAbsent(lambda, () => [])
          .add(ReactionSummary.fromJson(row));
    }
    return grouped;
  }

  Future<void> applyReaction({
    required String logicalMessageId,
    required String emoji,
  }) async {
    await _client.rpc(
      'apply_message_reaction',
      params: {
        'p_logical_message_id': logicalMessageId,
        'p_emoji': emoji,
      },
    );
  }

  Future<void> withdrawReaction({required String logicalMessageId}) async {
    await _client.rpc(
      'withdraw_message_reaction',
      params: {'p_logical_message_id': logicalMessageId},
    );
  }

  Future<ChatMessage> sendToAddress({
    required String peerAddress,
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'text',
      body: body,
    );
  }

  Future<ChatMessage> sendGifToAddress({
    required String peerAddress,
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'gif',
      body: '',
      mediaUrl: mediaUrl,
    );
  }

  Future<ChatMessage> sendVoiceToAddress({
    required String peerAddress,
    required String mediaUrl,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
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

  Future<ChatMessage> sendLocationToAddress({
    required String peerAddress,
    required double latitude,
    required double longitude,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'location',
      body: '',
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<ChatMessage> sendImageToAddress({
    required String peerAddress,
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'image',
      body: body,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  Future<ChatMessage> sendVideoToAddress({
    required String peerAddress,
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) {
    return _sendToAddress(
      peerAddress: peerAddress,
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'video',
      body: body,
      mediaUrl: mediaUrl,
      durationSeconds: durationSeconds,
      mediaMime: mediaMime,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  Future<ChatMessage> _sendToAddress({
    required String peerAddress,
    required String currentUserId,
    required String clientMessageId,
    required String contentType,
    required String body,
    String? mediaUrl,
    int? durationSeconds,
    String? mediaMime,
    int? mediaSizeBytes,
    double? latitude,
    double? longitude,
  }) async {
    final params = {
      'p_peer_address': peerAddress.trim().toLowerCase(),
      'p_body': body,
      'p_client_message_id': clientMessageId,
      'p_content_type': contentType,
      'p_media_url': ?mediaUrl,
      'p_duration_seconds': ?durationSeconds,
      'p_media_mime': ?mediaMime,
      'p_media_size_bytes': ?mediaSizeBytes,
      'p_latitude': ?latitude,
      'p_longitude': ?longitude,
    };

    final row = await _client.rpc('send_message_to_address', params: params);

    return ChatMessage.fromJson(
      json: row as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }

  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerAddress,
    required void Function(ChatMessage message) onMessage,
    void Function(String logicalMessageId)? onReactionFact,
  }) {
    final normalizedPeer = peerAddress.trim().toLowerCase();

    bool isRelevant(Map<String, dynamic> record) =>
        isMailboxPeerMessageRelevant(
          record: record,
          currentUserId: currentUserId,
          peerAddress: normalizedPeer,
        );

    void handle(PostgresChangePayload payload) {
      final record = payload.newRecord;
      if (record.isEmpty || !isRelevant(record)) return;
      final message = ChatMessage.fromJson(
        json: record,
        currentUserId: currentUserId,
      );
      final isDeliveryTick = payload.eventType == PostgresChangeEvent.update;
      if (!message.hasRenderableContent && !isDeliveryTick) return;
      onMessage(message);
    }

    void handleReaction(PostgresChangePayload payload) {
      if (onReactionFact == null) return;
      final record = payload.newRecord;
      if (record.isEmpty) return;
      final lambda = record['logical_message_id'] as String?;
      if (lambda == null || lambda.isEmpty) return;
      onReactionFact(lambda);
    }

    final channel = _client
        .channel('messages-peer-$currentUserId-$normalizedPeer')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'archive_user_id',
            value: currentUserId,
          ),
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'archive_user_id',
            value: currentUserId,
          ),
          callback: handle,
        );

    if (onReactionFact != null) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_reaction_facts',
        callback: handleReaction,
      );
    }

    return channel.subscribe();
  }

  void disposeChannel(RealtimeChannel? channel) {
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }
}
