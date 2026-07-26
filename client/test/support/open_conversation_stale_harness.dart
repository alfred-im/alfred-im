// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';
import 'package:alfred_client/services/profile_service.dart';

import 'fake_messaging_services.dart';

/// Fixture condivise per «no stale chat» — dominio navigation/invariants.md
class OpenConversationStaleHarness {
  OpenConversationStaleHarness._();

  static ProfileSummary profile(String id, String username) => ProfileSummary(
        id: id,
        username: username,
        displayName: username,
      );

  static ChatPeer peer(ProfileSummary profile) =>
      ChatPeer.fromProfile(profile: profile);

  static ProfileService profileService(Map<String, ProfileSummary> peers) =>
      _HarnessProfileService(peers);

  static Future<AccountSession> session({
    required String accountId,
    required String username,
    List<ChatPeer> inboxPeers = const [],
    Map<String, ProfileSummary> peersById = const {},
  }) {
    return AccountSession.createForTest(
      profile: profile(accountId, username),
      client: createTestSupabaseClient(),
      inboxService: FakeInboxService(peers: inboxPeers),
      profileService: _HarnessProfileService(peersById),
    );
  }

  static void seedStaleChat({
    required AccountManager manager,
    required String accountId,
    required String stalePeerId,
    required String staleUsername,
  }) {
    manager.applyAccountViewState(
      accountId,
      (view) => view.openChat(peer(profile(stalePeerId, staleUsername))),
    );
  }
}

class _HarnessProfileService extends ProfileService {
  _HarnessProfileService(this._peers) : super(createTestSupabaseClient());

  final Map<String, ProfileSummary> _peers;

  @override
  Future<ProfileSummary?> findById(String id) async => _peers[id];
}

class OpenConversationStaleFixture {
  OpenConversationStaleFixture({
    required this.manager,
    required this.nav,
  });

  final AccountManager manager;
  final NavigationCoordinator nav;
}
