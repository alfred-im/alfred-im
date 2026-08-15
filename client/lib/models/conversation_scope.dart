// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/account_session.dart';
import 'chat_peer.dart';

/// Ambito atomico di una conversazione aperta: account + peer + generazione sessione + caricamento.
///
/// Unico contratto per load, realtime, invio e render messaggi — vedi PROM-CONVERSATION-SCOPE.
class ConversationScope {
  const ConversationScope({
    required this.focusUserId,
    required this.peerProfileId,
    required this.sessionEpoch,
    this.loadSeq = 0,
  }) : assert(focusUserId != peerProfileId);

  final String focusUserId;
  final String peerProfileId;

  /// Incrementato a ogni restore/dispose sessione GoTrue ([SessionAuthority.identityGeneration]).
  final int sessionEpoch;

  /// Alias canonico dominio — stesso valore di [sessionEpoch].
  int get identityGeneration => sessionEpoch;

  /// Incrementato su invalidazione forte (switch account, cambio peer, chiusura, epoch).
  final int loadSeq;

  factory ConversationScope.fromSession(
    AccountSession session,
    ChatPeer peer, {
    int loadSeq = 0,
  }) {
    return ConversationScope(
      focusUserId: session.userId,
      peerProfileId: peer.profileId,
      sessionEpoch: session.epoch,
      loadSeq: loadSeq,
    );
  }

  ConversationScope copyWith({
    int? sessionEpoch,
    int? loadSeq,
  }) {
    return ConversationScope(
      focusUserId: focusUserId,
      peerProfileId: peerProfileId,
      sessionEpoch: sessionEpoch ?? this.sessionEpoch,
      loadSeq: loadSeq ?? this.loadSeq,
    );
  }

  bool matchesSession(AccountSession session) =>
      session.userId == focusUserId && session.epoch == sessionEpoch;

  bool matchesPeer(ChatPeer peer) => peer.profileId == peerProfileId;

  bool matches(AccountSession session, ChatPeer peer) =>
      matchesSession(session) && matchesPeer(peer);

  /// Stessa conversazione (account + peer), indipendentemente da epoch/loadSeq.
  bool isSameConversationAs(ConversationScope other) =>
      focusUserId == other.focusUserId &&
      peerProfileId == other.peerProfileId;

  /// Identità conversazione senza generazione sessione/caricamento.
  bool isSameConversation({
    required String focusUserId,
    required String peerProfileId,
  }) =>
      this.focusUserId == focusUserId && this.peerProfileId == peerProfileId;

  Key get providerKey => ValueKey(
        Object.hash(
          'conversation-scope',
          focusUserId,
          peerProfileId,
          sessionEpoch,
          loadSeq,
        ),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationScope &&
          focusUserId == other.focusUserId &&
          peerProfileId == other.peerProfileId &&
          sessionEpoch == other.sessionEpoch &&
          loadSeq == other.loadSeq;

  @override
  int get hashCode =>
      Object.hash(focusUserId, peerProfileId, sessionEpoch, loadSeq);
}
