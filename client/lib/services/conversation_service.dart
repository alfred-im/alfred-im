import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import 'supabase_bootstrap.dart';

class ConversationService {
  Future<List<Conversation>> fetchConversations(String userId) async {
    final participantRows = await supabase
        .from('conversation_participants')
        .select('*, conversations(*)')
        .eq('profile_id', userId)
        .order('joined_at', ascending: false);

    final conversations = <Conversation>[];

    for (final row in participantRows as List<dynamic>) {
      final participant = row as Map<String, dynamic>;
      final conversation = participant['conversations'] as Map<String, dynamic>?;
      if (conversation == null) continue;

      final displayName = await _resolveDisplayName(
        userId: userId,
        conversation: conversation,
        participant: participant,
      );

      conversations.add(
        Conversation.fromJoinedRow(
          conversation: conversation,
          participant: participant,
          displayName: displayName,
          avatarKey: displayName,
        ),
      );
    }

    conversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  Future<String> _resolveDisplayName({
    required String userId,
    required Map<String, dynamic> conversation,
    required Map<String, dynamic> participant,
  }) async {
    if (conversation['title'] != null &&
        (conversation['title'] as String).isNotEmpty) {
      return conversation['title'] as String;
    }

    final conversationId = conversation['id'] as String;

    final others = await supabase
        .from('conversation_participants')
        .select('profile_id, contact_id, profiles(display_name), contacts(display_name)')
        .eq('conversation_id', conversationId)
        .neq('profile_id', userId);

    if ((others as List).isEmpty) {
      return 'Conversazione';
    }

    final other = others.first;
    final profile = other['profiles'] as Map<String, dynamic>?;
    if (profile != null && profile['display_name'] != null) {
      return profile['display_name'] as String;
    }
    final contact = other['contacts'] as Map<String, dynamic>?;
    if (contact != null && contact['display_name'] != null) {
      return contact['display_name'] as String;
    }
    return 'Contatto';
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
