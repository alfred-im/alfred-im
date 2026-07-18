// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/chat_peer.dart';
import 'navigation_effects.dart';

/// Stato shell navigation — `docs/model/uml/navigation/navigation-shell-state.puml`.
enum NavigationShellState {
  inboxVisible,
  chatOpen,
  groupShell,
}

sealed class NavigationEvent {
  const NavigationEvent();
}

final class SwitchToAccount extends NavigationEvent {
  const SwitchToAccount(this.accountUserId);
  final String accountUserId;
}

final class OpenPeerOnFocusedAccount extends NavigationEvent {
  const OpenPeerOnFocusedAccount(this.peer);
  final ChatPeer peer;
}

final class OpenConversationOnAccount extends NavigationEvent {
  const OpenConversationOnAccount({
    required this.accountUserId,
    required this.peerProfileId,
    this.allowProfileFallback = true,
  });

  final String accountUserId;
  final String peerProfileId;
  final bool allowProfileFallback;
}

final class OpenFromPushTap extends NavigationEvent {
  const OpenFromPushTap({
    required this.accountUserId,
    required this.peerProfileId,
  });

  final String accountUserId;
  final String peerProfileId;
}

/// Macchina navigation — unico ingresso shell inbox/chat.
class NavigationMachine {
  NavigationMachine(this._effects);

  final NavigationEffects _effects;

  NavigationShellState shellState = NavigationShellState.inboxVisible;

  Future<void> send(NavigationEvent event) async {
    switch (event) {
      case SwitchToAccount(:final accountUserId):
        await _effects.focusAccount(accountUserId);
        shellState = NavigationShellState.inboxVisible;
      case OpenPeerOnFocusedAccount(:final peer):
        _effects.openPeerOnFocusedAccount(peer);
        shellState = NavigationShellState.chatOpen;
      case OpenConversationOnAccount(
        :final accountUserId,
        :final peerProfileId,
        :final allowProfileFallback,
      ):
        final ok = await _effects.openConversationOnAccount(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          allowProfileFallback: allowProfileFallback,
        );
        shellState = ok
            ? NavigationShellState.chatOpen
            : NavigationShellState.inboxVisible;
      case OpenFromPushTap(:final accountUserId, :final peerProfileId):
        final ok = await _effects.openConversationOnAccount(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          allowProfileFallback: false,
        );
        shellState = ok
            ? NavigationShellState.chatOpen
            : NavigationShellState.inboxVisible;
    }
  }
}
