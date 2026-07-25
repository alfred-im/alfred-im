// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/voice_config.dart';
import '../models/message.dart';

/// RPC e realtime archivio owner (broadcast gruppo / list_owner_messages).
class GroupArchiveService {
  GroupArchiveService(this._client);

  final SupabaseClient _client;

  Future<List<ChatMessage>> fetchOwnerMessages({
    required String currentUserId,
    int limit = 200,
  }) async {
    final rows = await _client.rpc(
      'list_owner_messages',
      params: {'p_limit': limit},
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

  Future<ChatMessage> broadcastToAllowlist({
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _broadcastToAllowlist(
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'text',
      body: body,
    );
  }

  Future<ChatMessage> broadcastGifToAllowlist({
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _broadcastToAllowlist(
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'gif',
      mediaUrl: mediaUrl,
    );
  }

  Future<ChatMessage> broadcastVoiceToAllowlist({
    required String mediaUrl,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _broadcastToAllowlist(
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'voice',
      mediaUrl: mediaUrl,
      durationSeconds: durationSeconds,
      mediaMime: VoiceConfig.canonicalMime,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  Future<ChatMessage> broadcastLocationToAllowlist({
    required double latitude,
    required double longitude,
    required String currentUserId,
    required String clientMessageId,
  }) {
    return _broadcastToAllowlist(
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'location',
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<ChatMessage> broadcastImageToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) {
    return _broadcastToAllowlist(
      currentUserId: currentUserId,
      clientMessageId: clientMessageId,
      contentType: 'image',
      body: body,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      mediaSizeBytes: mediaSizeBytes,
    );
  }

  Future<ChatMessage> broadcastVideoToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) {
    return _broadcastToAllowlist(
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

  Future<ChatMessage> _broadcastToAllowlist({
    required String currentUserId,
    required String clientMessageId,
    required String contentType,
    String body = '',
    String? mediaUrl,
    int? durationSeconds,
    String? mediaMime,
    int? mediaSizeBytes,
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, dynamic>{
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

    final row = await _client.rpc('broadcast_message_to_allowlist', params: params);
    return ChatMessage.fromJson(
      json: row as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }

  RealtimeChannel subscribeToOwnerMessages({
    required String currentUserId,
    required void Function(ChatMessage message) onMessage,
  }) {
    void handle(PostgresChangePayload payload) {
      final record = payload.newRecord;
      if (record.isEmpty) return;
      if (record['owner_id'] != currentUserId) return;
      final message = ChatMessage.fromJson(
        json: record,
        currentUserId: currentUserId,
      );
      final isDeliveryTick = payload.eventType == PostgresChangeEvent.update;
      if (!message.hasRenderableContent && !isDeliveryTick) return;
      onMessage(message);
    }

    return _client
        .channel('messages-owner-$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'owner_id',
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
            column: 'owner_id',
            value: currentUserId,
          ),
          callback: handle,
        )
        .subscribe();
  }
}
