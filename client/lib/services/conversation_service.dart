import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import 'supabase_bootstrap.dart';

class ConversationService {
  Future<List<Conversation>> fetchConversations() async {
    final rows = await supabase.rpc('list_conversations');

    final conversations = (rows as List<dynamic>)
        .map(
          (row) => Conversation.fromListRpcRow(
            row as Map<String, dynamic>,
          ),
        )
        .toList();

    conversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  Future<String> openConversationFromContact(String contactId) async {
    final result = await supabase.rpc(
      'get_or_create_conversation_from_contact',
      params: {'p_contact_id': contactId},
    );
    return result as String;
  }

  Future<void> markRead(String conversationId) async {
    await supabase.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  RealtimeChannel subscribeToConversationList(
    String userId,
    void Function() onChange,
  ) {
    return supabase
        .channel('conversations-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
