// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

@Tags(['diagnostic'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/coordinators/navigation_coordinator.dart';
import 'package:alfred_client/services/outbound_message_queue.dart';
import 'package:alfred_client/utils/conversation_scope_guard.dart';
import 'package:alfred_client/utils/diagnostic_log.dart';

import '../support/diagnostic_harness.dart';
import '../support/fake_message_media_service.dart';
import '../support/fake_messaging_services.dart';
import '../support/media_test_fixtures.dart';
import '../support/mock_path_provider.dart';

/// Regressione bug PWA: dopo reconcile epoch, invio (anche media) non deve
/// fallire con scope_mismatch / sessione scaduta.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiagnosticHarness harness;

  setUp(() {
    setUpMockPathProvider();
    SharedPreferences.setMockInitialValues({});
    harness = DiagnosticHarness();
  });
  tearDown(() => harness.dispose());

  test('epoch reconciled: scope guard attivo e sendImage ok', () async {
    const ownerId = 'user-a';
    const peerId = 'peer-b';
    const peerProfile = ProfileSummary(
      id: peerId,
      username: 'peer_b',
      displayName: 'Peer B',
    );

    final client = createTestSupabaseClient();
    final sessionV1 = await AccountSession.createForTest(
      profile: const ProfileSummary(
        id: ownerId,
        username: 'user_a',
        displayName: 'User A',
      ),
      client: client,
      messageService: FakeMessageService(client),
    );
    final sessionV2 = await AccountSession.createForTest(
      profile: sessionV1.profile,
      client: client,
      messageService: FakeMessageService(client),
    );
    expect(sessionV2.epoch, isNot(sessionV1.epoch));

    final manager = AccountManager()..focusTestSession(sessionV2);
    final navigation = NavigationCoordinator(manager);
    final peer = ChatPeer(profile: peerProfile);
    final frozenScope = ConversationScope.fromSession(sessionV1, peer);
    navigation.machine.commitScope(frozenScope);

    navigation.machine.reconcileSessionEpoch(sessionV2);
    final reconciled = navigation.committedScope!;
    expect(reconciled.sessionEpoch, sessionV2.epoch);
    expect(reconciled.isSameConversationAs(frozenScope), isTrue);
    expect(reconciled, isNot(equals(frozenScope)));

    expect(
      isMessagesScopeActive(
        scope: frozenScope,
        committedScope: reconciled,
        peer: peer,
        liveSession: sessionV2,
        isConversationReady: (_, _) => navigation.isConversationReady(
          session: sessionV2,
          peer: peer,
        ),
      ),
      isTrue,
    );

    final mediaService = FakeMessageMediaService();
    final controller = MessagesController(
      scope: frozenScope,
      messageStore: testMessageStoreFor(frozenScope),
      userId: ownerId,
      peerProfileId: peerId,
      messageService: sessionV2.messageService,
      messageMediaService: mediaService,
      inboxService: FakeInboxService(),
      outboundQueue: OutboundMessageQueue(),
      hasValidSession: () => true,
      isScopeCommitted: () => isMessagesScopeActive(
        scope: frozenScope,
        committedScope: navigation.committedScope,
        peer: peer,
        liveSession: sessionV2,
        isConversationReady: (_, _) => navigation.isConversationReady(
          session: sessionV2,
          peer: peer,
        ),
      ),
    );
    await waitForMessagesController(controller);

    harness.clear();
    await controller.sendImage(bytes: kJpegBytes);

    expect(controller.error, isNull);
    expect(mediaService.imageUploads, hasLength(1));
    expect(
      harness.any(flow: DiagnosticFlows.scope, failureOnly: true),
      isFalse,
    );
    expect(
      harness.any(
        flow: DiagnosticFlows.messaging,
        phaseContains: 'send.done',
      ),
      isTrue,
    );

    controller.dispose();
  });
}
