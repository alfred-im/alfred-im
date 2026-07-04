import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/providers/inbox_controller.dart';
import 'package:alfred_client/services/inbox_service.dart';

import '../support/fake_messaging_services.dart';

class _SpyInboxService extends InboxService {
  _SpyInboxService(this._spyClient) : super(_spyClient);

  final SupabaseClient _spyClient;
  String? subscribedUserId;

  @override
  Future<List<ChatPeer>> fetchInbox() async => [];

  @override
  RealtimeChannel subscribeToInbox(
    String userId,
    void Function() onChange,
  ) {
    subscribedUserId = userId;
    return _spyClient.channel('spy-inbox-$userId').subscribe();
  }
}

void main() {
  test('InboxController subscribes realtime on owner_id archive', () async {
    final client = createTestSupabaseClient();
    final spy = _SpyInboxService(client);
    const userId = 'efd885fe-b36e-48fc-a796-0e3f153e40d6';

    final controller = InboxController(
      userId: userId,
      inboxService: spy,
      enableRealtime: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.dispose();

    expect(spy.subscribedUserId, userId);
  });
}
