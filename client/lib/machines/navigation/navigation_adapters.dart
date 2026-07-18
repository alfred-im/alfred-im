// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../../models/chat_peer.dart';
import 'navigation_machine.dart';

/// Adapter UI / contesti esterni → eventi [NavigationMachine].
class NavigationAdapters {
  NavigationAdapters(this._machine);

  final NavigationMachine _machine;

  Future<void> switchToAccount(String accountUserId) {
    return _machine.send(SwitchToAccount(accountUserId));
  }

  void openPeerOnFocusedAccount(ChatPeer peer) {
    unawaited(_machine.send(OpenPeerOnFocusedAccount(peer)));
  }

  Future<bool> openConversationOnAccount({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    await _machine.send(
      OpenConversationOnAccount(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
        allowProfileFallback: allowProfileFallback,
      ),
    );
    return _machine.shellState == NavigationShellState.chatOpen;
  }

  Future<bool> openFromPushTap({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    await _machine.send(
      OpenFromPushTap(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
      ),
    );
    return _machine.shellState == NavigationShellState.chatOpen;
  }

  Future<bool> openFromShareableLink({
    required String accountUserId,
    required String peerProfileId,
  }) async {
    await _machine.send(
      OpenFromShareableLink(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
      ),
    );
    return _machine.shellState == NavigationShellState.chatOpen;
  }

  Future<bool> openFromCompose({
    required String accountUserId,
    required String peerProfileId,
    bool allowProfileFallback = true,
  }) async {
    await _machine.send(
      OpenFromCompose(
        accountUserId: accountUserId,
        peerProfileId: peerProfileId,
        allowProfileFallback: allowProfileFallback,
      ),
    );
    return _machine.shellState == NavigationShellState.chatOpen;
  }

  Future<void> closeConversation() {
    return _machine.send(const CloseConversation());
  }

  Future<void> openGroupChat() {
    return _machine.send(const OpenGroupChat());
  }

  Future<void> backToGroupHome() {
    return _machine.send(const BackToGroupHome());
  }

  void mergeActivePeerFromInbox(ChatPeer inboxRow) {
    unawaited(_machine.send(MergeActivePeerFromInbox(inboxRow)));
  }
}
