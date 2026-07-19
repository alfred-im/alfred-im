// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/navigation/navigation_adapters.dart';
import 'package:alfred_client/machines/navigation/navigation_effects.dart';
import 'package:alfred_client/machines/navigation/navigation_machine.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/open_conversation_source.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/account_manager.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/navigation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_messaging_services.dart';

class _RecordingNavigationEffects implements NavigationEffects {
  String? lastFocusAccountId;
  ChatPeer? lastPeer;
  String? lastOpenAccountId;
  String? lastOpenPeerId;
  OpenConversationSource? lastSource;
  bool? lastAllowFallback;
  bool openResult = true;
  bool focusedIsGroup = false;
  int closeCount = 0;
  int openGroupChatCount = 0;
  int backToGroupHomeCount = 0;

  @override
  bool get focusedAccountIsGroup => focusedIsGroup;

  @override
  Future<void> focusAccount(String accountUserId) async {
    lastFocusAccountId = accountUserId;
  }

  @override
  Future<bool> openConversation({
    required String accountUserId,
    required String peerProfileId,
    required OpenConversationSource source,
    bool allowProfileFallback = true,
  }) async {
    lastOpenAccountId = accountUserId;
    lastOpenPeerId = peerProfileId;
    lastSource = source;
    lastAllowFallback = allowProfileFallback;
    return openResult;
  }

  @override
  void restoreCommittedScopeFromViewState() {}

  @override
  void openPeerOnFocusedAccount(ChatPeer peer) {
    lastPeer = peer;
  }

  @override
  void closeConversation() {
    closeCount++;
  }

  @override
  void openGroupChat() {
    openGroupChatCount++;
  }

  @override
  void backToGroupHome() {
    backToGroupHomeCount++;
  }

  @override
  void mergeActivePeerFromInbox(ChatPeer inboxRow) {}
}

ChatPeer _peer(String id) => ChatPeer(
      profile: ProfileSummary(
        id: id,
        username: id,
        displayName: id,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationMachine shell state', () {
    test('SwitchToAccount su utente → inboxVisible', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(const SwitchToAccount('user-a'));

      expect(machine.shellState, NavigationShellState.inboxVisible);
      expect(effects.lastFocusAccountId, 'user-a');
    });

    test('SwitchToAccount su gruppo → groupShell', () async {
      final effects = _RecordingNavigationEffects()..focusedIsGroup = true;
      final machine = NavigationMachine(effects);

      await machine.send(const SwitchToAccount('group-a'));

      expect(machine.shellState, NavigationShellState.groupShell);
    });

    test('OpenPeerOnFocusedAccount → chatOpen', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(OpenPeerOnFocusedAccount(_peer('peer-b')));

      expect(machine.shellState, NavigationShellState.chatOpen);
      expect(effects.lastPeer?.profileId, 'peer-b');
    });

    test('OpenConversationOnAccount ok → chatOpen', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(
        const OpenConversationOnAccount(
          accountUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
      );

      expect(machine.shellState, NavigationShellState.chatOpen);
      expect(effects.lastAllowFallback, isTrue);
    });

    test('OpenConversationOnAccount rejected → inboxVisible', () async {
      final effects = _RecordingNavigationEffects()..openResult = false;
      final machine = NavigationMachine(effects);

      await machine.send(
        const OpenConversationOnAccount(
          accountUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
      );

      expect(machine.shellState, NavigationShellState.inboxVisible);
    });

    test('OpenFromShareableLink usa source shareableLink', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(
        const OpenFromShareableLink(
          accountUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
      );

      expect(machine.shellState, NavigationShellState.chatOpen);
      expect(effects.lastSource, OpenConversationSource.shareableLink);
      expect(effects.lastAllowFallback, isTrue);
    });

    test('OpenFromCompose usa stale clear e fallback profilo', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(
        const OpenFromCompose(
          accountUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
      );

      expect(machine.shellState, NavigationShellState.chatOpen);
      expect(effects.lastAllowFallback, isTrue);
    });

    test('OpenFromPushTap → chatOpen', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects);

      await machine.send(
        const OpenFromPushTap(
          accountUserId: 'user-a',
          peerProfileId: 'peer-b',
        ),
      );

      expect(machine.shellState, NavigationShellState.chatOpen);
      expect(effects.lastSource, OpenConversationSource.push);
    });

    test('CloseConversation → inboxVisible', () async {
      final effects = _RecordingNavigationEffects();
      final machine = NavigationMachine(effects)
        ..shellState = NavigationShellState.chatOpen;

      await machine.send(const CloseConversation());

      expect(machine.shellState, NavigationShellState.inboxVisible);
      expect(effects.closeCount, 1);
    });

    test('CloseConversation su gruppo → groupShell', () async {
      final effects = _RecordingNavigationEffects()..focusedIsGroup = true;
      final machine = NavigationMachine(effects)
        ..shellState = NavigationShellState.groupShell;

      await machine.send(const CloseConversation());

      expect(machine.shellState, NavigationShellState.groupShell);
      expect(effects.closeCount, 1);
    });

    test('OpenGroupChat e BackToGroupHome restano in groupShell', () async {
      final effects = _RecordingNavigationEffects()..focusedIsGroup = true;
      final machine = NavigationMachine(effects);
      final adapters = NavigationAdapters(machine);

      await adapters.openGroupChat();
      expect(machine.shellState, NavigationShellState.groupShell);
      expect(effects.openGroupChatCount, 1);

      await adapters.backToGroupHome();
      expect(machine.shellState, NavigationShellState.groupShell);
      expect(effects.backToGroupHomeCount, 1);
    });
  });

  group('NavigationMachine AccountViewState transitions', () {
    late AccountManager manager;
    late NavigationCoordinator nav;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      manager = AccountManager();
      nav = NavigationCoordinator(manager);
      manager.seedTestAccount('account-a');
      manager.seedTestAccount('account-b');
    });

    test('OpenPeerOnFocusedAccount aggiorna view state per account in focus', () async {
      final session = await _testSession('account-a');
      manager.focusTestSession(session);

      nav.openPeerOnFocusedAccount(_peer('peer-b'));

      expect(manager.viewState.activePeer?.profileId, 'peer-b');
      expect(manager.viewState.showInboxOnMobile, isFalse);
    });

    test('CloseConversation ripristina inbox mobile', () async {
      manager.focusTestSession(await _testSession('account-a'));
      nav.openPeerOnFocusedAccount(_peer('peer-b'));

      await nav.closeConversation();

      expect(manager.viewState.activePeer?.profileId, 'peer-b');
      expect(manager.viewState.showInboxOnMobile, isTrue);
    });

    test('OpenGroupChat e BackToGroupHome aggiornano groupChatOpen', () async {
      manager.focusTestSession(
        await _testSession(
          'account-a',
          profileKind: ProfileKind.group,
        ),
      );

      await nav.openGroupChat();
      expect(manager.viewState.groupChatOpen, isTrue);
      expect(manager.viewState.showInboxOnMobile, isFalse);

      await nav.backToGroupHome();
      expect(manager.viewState.groupChatOpen, isFalse);
      expect(manager.viewState.showInboxOnMobile, isTrue);
    });

    test('SwitchToAccount ripristina scope e shell chat da view-state', () async {
      manager.applyAccountViewState(
        'account-b',
        (view) => view.openChat(_peer('peer-x')),
      );
      manager.injectTestSession(await _testSession('account-a'));
      manager.injectTestSession(await _testSession('account-b'));
      manager.focusTestSession(await _testSession('account-a'));

      await nav.switchToAccount('account-b');

      expect(nav.committedScope?.peerProfileId, 'peer-x');
      expect(nav.machine.shellState, NavigationShellState.chatOpen);
    });

    test('setFocus preserva view state per account', () async {
      manager.injectTestSession(await _testSession('account-a'));
      manager.injectTestSession(await _testSession('account-b'));
      manager.focusTestSession(await _testSession('account-a'));

      await manager.setFocus('account-b');
      nav.openPeerOnFocusedAccount(_peer('peer-x'));

      await manager.setFocus('account-a');
      expect(manager.viewState.activePeer, isNull);

      await manager.setFocus('account-b');
      expect(manager.viewState.activePeer?.profileId, 'peer-x');
    });
  });
}

Future<AccountSession> _testSession(
  String id, {
  ProfileKind profileKind = ProfileKind.user,
}) {
  return AccountSession.createForTest(
    profile: ProfileSummary(
      id: id,
      username: id,
      displayName: id,
      profileKind: profileKind,
    ),
    client: createTestSupabaseClient(),
    inboxService: FakeInboxService(),
  );
}
