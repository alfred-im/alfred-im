// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/chat_peer.dart';
import '../models/conversation_scope.dart';
import '../services/account_session.dart';
import '../utils/diagnostic_log.dart';

/// Motivo per cui lo scope messaggi non è attivo — per diagnostica e test.
enum MessagesScopeInactiveReason {
  disposed,
  noCommittedScope,
  scopeMismatch,
  noLiveSession,
  focusMismatch,
  peerMismatch,
  conversationNotReady,
}

extension MessagesScopeInactiveReasonDiag on MessagesScopeInactiveReason {
  String get diagnosticCode => switch (this) {
        MessagesScopeInactiveReason.disposed => 'disposed',
        MessagesScopeInactiveReason.noCommittedScope => 'no_committed_scope',
        MessagesScopeInactiveReason.scopeMismatch => 'scope_mismatch',
        MessagesScopeInactiveReason.noLiveSession => 'no_live_session',
        MessagesScopeInactiveReason.focusMismatch => 'focus_mismatch',
        MessagesScopeInactiveReason.peerMismatch => 'peer_mismatch',
        MessagesScopeInactiveReason.conversationNotReady =>
          'conversation_not_ready',
      };
}

/// Valuta scope messaggi e restituisce il motivo di inattività (null = attivo).
MessagesScopeInactiveReason? diagnoseMessagesScopeInactive({
  required ConversationScope scope,
  required ConversationScope? committedScope,
  required ChatPeer peer,
  required AccountSession? liveSession,
  required bool Function(AccountSession session, ChatPeer peer)
      isConversationReady,
  bool disposed = false,
}) {
  if (disposed) return MessagesScopeInactiveReason.disposed;
  if (committedScope == null) {
    return MessagesScopeInactiveReason.noCommittedScope;
  }
  if (!committedScope.isSameConversationAs(scope)) {
    return MessagesScopeInactiveReason.scopeMismatch;
  }
  if (liveSession == null) return MessagesScopeInactiveReason.noLiveSession;
  if (liveSession.userId != scope.focusUserId) {
    return MessagesScopeInactiveReason.focusMismatch;
  }
  if (peer.profileId != scope.peerProfileId) {
    return MessagesScopeInactiveReason.peerMismatch;
  }
  if (!isConversationReady(liveSession, peer)) {
    return MessagesScopeInactiveReason.conversationNotReady;
  }
  return null;
}

/// Come [isMessagesScopeActive] ma con log strutturato su fallimento.
bool isMessagesScopeActive({
  required ConversationScope scope,
  required ConversationScope? committedScope,
  required ChatPeer peer,
  required AccountSession? liveSession,
  required bool Function(AccountSession session, ChatPeer peer)
      isConversationReady,
  bool disposed = false,
  bool logOnInactive = true,
}) {
  final reason = diagnoseMessagesScopeInactive(
    scope: scope,
    committedScope: committedScope,
    peer: peer,
    liveSession: liveSession,
    isConversationReady: isConversationReady,
    disposed: disposed,
  );
  if (reason == null) {
    return true;
  }
  if (logOnInactive) {
    DiagnosticHub.instance.emitFail(
      DiagnosticFlows.scope,
      'inactive',
      reason.diagnosticCode,
      data: {
        'focusUserId': scope.focusUserId,
        'peerProfileId': scope.peerProfileId,
        'scopeEpoch': scope.sessionEpoch,
        'scopeLoadSeq': scope.loadSeq,
        'committedEpoch': committedScope?.sessionEpoch,
        'committedLoadSeq': committedScope?.loadSeq,
        'liveUserId': liveSession?.userId,
        'liveEpoch': liveSession?.epoch,
      },
    );
  }
  return false;
}
