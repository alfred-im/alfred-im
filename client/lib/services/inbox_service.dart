import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_peer.dart';

class InboxService {
  InboxService(this._client);

  final SupabaseClient _client;

  Future<List<ChatPeer>> fetchInbox() async {
    final rows = await _client.rpc('list_inbox');

    final peers = (rows as List<dynamic>)
        .map(
          (row) => ChatPeer.fromInboxRow(row as Map<String, dynamic>),
        )
        .toList();

    peers.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return peers;
  }

  Future<void> markRead(String peerProfileId) async {
    await _client.rpc(
      'mark_peer_read',
      params: {'p_peer_profile_id': peerProfileId},
    );
  }

  RealtimeChannel subscribeToInbox(
    String userId,
    void Function() onChange,
  ) {
    void handle(PostgresChangePayload _) => onChange();

    return _client
        .channel('inbox-messages-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_profile_id',
            value: userId,
          ),
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
