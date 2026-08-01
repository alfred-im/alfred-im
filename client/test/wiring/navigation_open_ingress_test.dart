// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/inbox_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

/// PROM-CONVERSATION-SCOPE-010 / SURF-INBOX-011 — refresh inbox non blocca ingresso chat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('navigation ingress — inbox loading', () {
    test('load(showLoadingIndicator: false) non imposta isLoading', () async {
      final inbox = InboxController(
        userId: 'user-a',
        inboxService: FakeInboxService(
          peers: const [
            ChatPeer(
              profile: ProfileSummary(
                id: 'peer-b',
                username: 'bob',
                displayName: 'Bob',
              ),
            ),
          ],
        ),
        enableRealtime: false,
      );

      await inbox.load(showLoadingIndicator: false);

      expect(inbox.isLoading, isFalse);
      expect(inbox.peers, isNotEmpty);
    });
  });
}
