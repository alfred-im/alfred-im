// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/services/inbox_service.dart';

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

class FakeInboxService extends InboxService {
  FakeInboxService({this.peers = const []}) : super(createTestSupabaseClient());

  final List<ChatPeer> peers;
  int fetchInboxCalls = 0;

  @override
  Future<List<ChatPeer>> fetchInbox() async {
    fetchInboxCalls++;
    return List<ChatPeer>.from(peers);
  }
}
