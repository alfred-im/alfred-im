// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';
import 'package:alfred_client/services/profile_service.dart';

import '../support/fake_messaging_services.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

ProfileSummary _profile(String id, String username) => ProfileSummary(
      id: id,
      username: username,
      displayName: username,
    );

ChatPeer _peer(ProfileSummary profile) => ChatPeer.fromProfile(profile: profile);

/// Regressione PROM-PUSH-NOTIFY-030/036 — tap push 1:1 multi-account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountA = 'account-a';
  const accountB = 'account-b';
  const stalePeerId = 'stale-peer-y';
  const pushSenderId = 'push-sender-z';

  late AccountManager manager;
  late NavigationCoordinator nav;
  late AccountSession sessionA;
  late AccountSession sessionB;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = AccountManager();
    nav = NavigationCoordinator(manager);

    sessionA = await AccountSession.createForTest(
      profile: _profile(accountA, 'agent_a'),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(),
      profileService: _FakeProfileService({}),
    );
    sessionB = await AccountSession.createForTest(
      profile: _profile(accountB, 'agent_b'),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(
        peers: [_peer(_profile(pushSenderId, 'sender_z'))],
      ),
      profileService: _FakeProfileService({
        pushSenderId: _profile(pushSenderId, 'sender_z'),
      }),
    );

    manager.seedTestAccount(accountA);
    manager.seedTestAccount(accountB);
    manager.injectTestSession(sessionA);
    manager.injectTestSession(sessionB);
    manager.focusTestSession(sessionA);

    await manager.setFocus(accountB);
    manager.openConversation(_peer(_profile(stalePeerId, 'stale_y')));
    expect(manager.viewState.activePeer?.profileId, stalePeerId);

    await manager.setFocus(accountA);
    expect(manager.focusUserId, accountA);
  });

  test('tap push 1:1: focus B + peer in inbox → apre mittente corretto', () async {
    final ok = await nav.adapters.openFromPushTap(
      accountUserId: accountB,
      peerProfileId: pushSenderId,
    );

    expect(ok, isTrue);
    expect(manager.focusUserId, accountB);
    expect(manager.viewState.activePeer?.profileId, pushSenderId);
  });

  test('tap push 1:1: peer assente da inbox → fallback profilo, non chat stale', () async {
    final sessionBFallback = await AccountSession.createForTest(
      profile: _profile(accountB, 'agent_b'),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(),
      profileService: _FakeProfileService({
        pushSenderId: _profile(pushSenderId, 'sender_z'),
      }),
    );
    manager.injectTestSession(sessionBFallback);

    final ok = await nav.adapters.openFromPushTap(
      accountUserId: accountB,
      peerProfileId: pushSenderId,
    );

    expect(ok, isTrue);
    expect(manager.focusUserId, accountB);
    expect(manager.viewState.activePeer?.profileId, pushSenderId);
    expect(manager.viewState.activePeer?.profileId, isNot(stalePeerId));
  });

  test('tap push 1:1: peer irrisolvibile → inbox senza chat stale', () async {
    final ok = await nav.adapters.openFromPushTap(
      accountUserId: accountB,
      peerProfileId: 'unknown-not-in-inbox',
    );

    expect(ok, isFalse);
    expect(manager.focusUserId, accountB);
    expect(manager.viewState.activePeer, isNull);
  });

  test('switch focus a B senza tap mostra ancora chat stale', () async {
    await nav.switchToAccount(accountB);

    expect(manager.focusUserId, accountB);
    expect(manager.viewState.activePeer?.profileId, stalePeerId);
  });
}
