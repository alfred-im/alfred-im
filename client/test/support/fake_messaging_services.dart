import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/inbox_service.dart';
import 'package:alfred_client/services/message_service.dart';

SupabaseClient createTestSupabaseClient() {
  return SupabaseClient(
    'http://127.0.0.1',
    'test-anon-key',
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      autoRefreshToken: false,
    ),
  );
}

/// Chiave conversazione come in MessagesController.outboundQueueKey.
String conversationKey({
  required String userId,
  required String peerProfileId,
}) =>
    '$userId|$peerProfileId';

class FakeMessageService extends MessageService {
  FakeMessageService(this._clientForTest) : super(_clientForTest);

  final SupabaseClient _clientForTest;

  final Map<String, List<ChatMessage>> messagesByConversation = {};

  @override
  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
  }) async {
    return List<ChatMessage>.from(
      messagesByConversation[conversationKey(
            userId: currentUserId,
            peerProfileId: peerProfileId,
          )] ??
          const [],
    );
  }

  @override
  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerProfileId,
    required void Function(ChatMessage message) onMessage,
  }) {
    return _clientForTest
        .channel('test-$currentUserId-$peerProfileId')
        .subscribe();
  }
}

class FakeInboxService extends InboxService {
  FakeInboxService() : super(createTestSupabaseClient());

  final List<String> markReadCalls = [];

  @override
  Future<void> markRead(String peerProfileId) async {
    markReadCalls.add(peerProfileId);
  }
}

Future<void> waitForMessagesController(MessagesController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  // _init continua dopo load (markRead, realtime, notifyListeners).
  await Future<void>.delayed(const Duration(milliseconds: 30));
}
