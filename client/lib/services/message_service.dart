import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import 'supabase_bootstrap.dart';

class MessageService {
  Future<List<ChatMessage>> fetchMessages({
    required String conversationId,
    required String currentUserId,
    int limit = 100,
  }) async {
    final rows = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .filter('marker_type', 'is', null)
        .order('created_at', ascending: true)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (r) => ChatMessage.fromJson(
            json: r as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .where((m) => m.body.isNotEmpty)
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) async {
    final row = await supabase.rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_body': body,
        'p_client_message_id': clientMessageId,
      },
    );

    return ChatMessage.fromJson(
      json: row as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }

  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required String currentUserId,
    required void Function(ChatMessage message) onMessage,
  }) {
    return supabase
        .channel('messages-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            final message = ChatMessage.fromJson(
              json: record,
              currentUserId: currentUserId,
            );
            if (message.body.isEmpty) return;
            onMessage(message);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            onMessage(
              ChatMessage.fromJson(
                json: record,
                currentUserId: currentUserId,
              ),
            );
          },
        )
        .subscribe();
  }
}
