// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'notifications_effects.dart';

/// Stato gestione tap / pending open chat — regione parallela client.
enum NotificationsOpenChatState {
  idle,
  queued,
  processing,
}

/// Eventi — allineati a `docs/domain/notifications/commands-and-events.md`.
sealed class NotificationsEvent {
  const NotificationsEvent();
}

final class OpenChatFromNotification extends NotificationsEvent {
  const OpenChatFromNotification({
    required this.recipientUserId,
    required this.peerProfileId,
    required this.sessionReady,
    required this.hasOpenAccount,
  });

  final String recipientUserId;
  final String peerProfileId;
  final bool sessionReady;
  final bool hasOpenAccount;
}

final class SessionBecameReady extends NotificationsEvent {
  const SessionBecameReady();
}

/// Macchina notifications — interprete statechart client (open chat).
///
/// Ingresso open chat: [NotificationsAdapters] da [PushNotificationListener].
/// Sync subscription: [PushCoordinator] (non passa da questa macchina).
class NotificationsMachine {
  NotificationsMachine({this._effects});

  final NotificationsEffects? _effects;

  NotificationsOpenChatState openChatState = NotificationsOpenChatState.idle;

  final List<({String recipientUserId, String peerProfileId})> _pendingWhileBusy =
      [];
  bool _openChatChainBusy = false;

  void send(NotificationsEvent event) {
    switch (event) {
      case OpenChatFromNotification():
        _handleOpenChatFromNotification(event);
      case SessionBecameReady():
        _drainQueuedOpenChat();
    }
  }

  void _handleOpenChatFromNotification(OpenChatFromNotification event) {
    if (_openChatChainBusy) {
      _pendingWhileBusy.add((
        recipientUserId: event.recipientUserId,
        peerProfileId: event.peerProfileId,
      ));
      openChatState = NotificationsOpenChatState.queued;
      return;
    }
    if (!event.sessionReady) {
      openChatState = NotificationsOpenChatState.queued;
      _effects?.persistPendingOpenChat(
        recipientUserId: event.recipientUserId,
        peerProfileId: event.peerProfileId,
      );
      return;
    }
    if (!event.hasOpenAccount) {
      openChatState = NotificationsOpenChatState.idle;
      _effects?.clearPendingOpenChat();
      return;
    }
    _startOpenChatProcessing(event.recipientUserId, event.peerProfileId);
  }

  void _drainQueuedOpenChat() {
    if (_openChatChainBusy || _pendingWhileBusy.isEmpty) return;
    final next = _pendingWhileBusy.removeAt(0);
    _startOpenChatProcessing(next.recipientUserId, next.peerProfileId);
  }

  void _startOpenChatProcessing(String recipientUserId, String peerProfileId) {
    _openChatChainBusy = true;
    openChatState = NotificationsOpenChatState.processing;
    final effects = _effects;
    if (effects == null) {
      _completeOpenChat(forwarded: true);
      return;
    }
    effects
        .forwardOpenFromPushTap(
          recipientUserId: recipientUserId,
          peerProfileId: peerProfileId,
        )
        .then((forwarded) => _completeOpenChat(forwarded: forwarded))
        .catchError((_) => _completeOpenChat(forwarded: false));
  }

  void _completeOpenChat({required bool forwarded}) {
    _openChatChainBusy = false;
    openChatState = NotificationsOpenChatState.idle;
    _effects?.clearPendingOpenChat();
    if (_pendingWhileBusy.isNotEmpty) {
      _drainQueuedOpenChat();
    }
  }
}
