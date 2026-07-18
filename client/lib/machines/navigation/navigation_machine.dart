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

/// Adapter shareable-link → `openConversationOnAccount` (clear stale + fallback).
final class OpenFromShareableLink extends NavigationEvent {
  const OpenFromShareableLink({
    required this.accountUserId,
    required this.peerProfileId,
  });

  final String accountUserId;
  final String peerProfileId;
}

/// Nuovo messaggio da indirizzo compose — stesso percorso di link con stale clear.
final class OpenFromCompose extends NavigationEvent {
  const OpenFromCompose({
    required this.accountUserId,
    required this.peerProfileId,
    this.allowProfileFallback = true,
  });

  final String accountUserId;
  final String peerProfileId;
  final bool allowProfileFallback;
}

/// Back mobile / chiudi chat — inbox o group home.
final class CloseConversation extends NavigationEvent {
  const CloseConversation();
}

final class OpenGroupChat extends NavigationEvent {
  const OpenGroupChat();
}

final class BackToGroupHome extends NavigationEvent {
  const BackToGroupHome();
}

/// Aggiorna metadati peer attivo da riga inbox (preview, timestamp).
final class MergeActivePeerFromInbox extends NavigationEvent {
  const MergeActivePeerFromInbox(this.inboxRow);
  final ChatPeer inboxRow;
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
        shellState = _effects.focusedAccountIsGroup
            ? NavigationShellState.groupShell
            : NavigationShellState.inboxVisible;
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
            : _effects.focusedAccountIsGroup
                ? NavigationShellState.groupShell
                : NavigationShellState.inboxVisible;
      case OpenFromPushTap(:final accountUserId, :final peerProfileId):
        final ok = await _effects.openConversationFromPushTap(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
        );
        shellState = ok
            ? NavigationShellState.chatOpen
            : _effects.focusedAccountIsGroup
                ? NavigationShellState.groupShell
                : NavigationShellState.inboxVisible;
      case OpenFromShareableLink(:final accountUserId, :final peerProfileId):
        final ok = await _effects.openConversationOnAccount(
          accountUserId: accountUserId,
          peerProfileId: peerProfileId,
          allowProfileFallback: true,
        );
        shellState = ok
            ? NavigationShellState.chatOpen
            : _effects.focusedAccountIsGroup
                ? NavigationShellState.groupShell
                : NavigationShellState.inboxVisible;
      case OpenFromCompose(
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
            : _effects.focusedAccountIsGroup
                ? NavigationShellState.groupShell
                : NavigationShellState.inboxVisible;
      case CloseConversation():
        _effects.closeConversation();
        shellState = _effects.focusedAccountIsGroup
            ? NavigationShellState.groupShell
            : NavigationShellState.inboxVisible;
      case OpenGroupChat():
        _effects.openGroupChat();
        shellState = NavigationShellState.groupShell;
      case BackToGroupHome():
        _effects.backToGroupHome();
        shellState = NavigationShellState.groupShell;
      case MergeActivePeerFromInbox(:final inboxRow):
        _effects.mergeActivePeerFromInbox(inboxRow);
    }
  }
}
