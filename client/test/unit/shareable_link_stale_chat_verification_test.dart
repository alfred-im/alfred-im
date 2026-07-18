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

/// Regressione PROM-SHAREABLE-LINK-004/024 — link #peer/chat senza chat stale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 'account-a';
  const stalePeerId = 'stale-peer-y';
  const linkPeerId = 'link-peer-z';

  late AccountManager manager;
  late NavigationCoordinator nav;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = AccountManager();
    nav = NavigationCoordinator(manager);

    final session = await AccountSession.createForTest(
      profile: _profile(accountId, 'agent_a'),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(
        peers: [_peer(_profile(linkPeerId, 'link_z'))],
      ),
      profileService: _FakeProfileService({
        linkPeerId: _profile(linkPeerId, 'link_z'),
      }),
    );

    manager.focusTestSession(session);

    manager.openConversation(_peer(_profile(stalePeerId, 'stale_y')));
    expect(manager.viewState.activePeer?.profileId, stalePeerId);
  });

  test('link #peer/chat: apre peer linkato e non lascia chat stale', () async {
    final ok = await nav.openConversationOnAccount(
      accountUserId: accountId,
      peerProfileId: linkPeerId,
    );

    expect(ok, isTrue);
    expect(manager.viewState.activePeer?.profileId, linkPeerId);
    expect(manager.viewState.activePeer?.profileId, isNot(stalePeerId));
  });

  test('link #peer/chat: peer irrisolvibile → inbox senza chat stale', () async {
    final ok = await nav.openConversationOnAccount(
      accountUserId: accountId,
      peerProfileId: 'unknown-peer',
      allowProfileFallback: false,
    );

    expect(ok, isFalse);
    expect(manager.viewState.activePeer, isNull);
  });

  test('link #peer/chat: fallback profilo se assente da inbox', () async {
    final session = await AccountSession.createForTest(
      profile: _profile(accountId, 'agent_a'),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(),
      profileService: _FakeProfileService({
        linkPeerId: _profile(linkPeerId, 'link_z'),
      }),
    );
    manager.injectTestSession(session);

    final ok = await nav.openConversationOnAccount(
      accountUserId: accountId,
      peerProfileId: linkPeerId,
    );

    expect(ok, isTrue);
    expect(manager.viewState.activePeer?.profileId, linkPeerId);
  });
}
