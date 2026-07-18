// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'notifications_effects.dart';

/// Stato subscription lato client — allineato a
/// `docs/model/uml/notifications/notifications-client-state.puml`.
enum NotificationsSubscriptionState {
  pushUnsupported,
  permissionDenied,
  idle,
  syncing,
  active,
}

/// Stato gestione tap / pending open chat — regione parallela client.
enum NotificationsOpenChatState {
  idle,
  queued,
  processing,
}

/// Eventi — stessi nomi di `docs/domain/notifications/commands-and-events.md`.
sealed class NotificationsEvent {
  const NotificationsEvent();
}

final class PushUnsupportedDetected extends NotificationsEvent {
  const PushUnsupportedDetected();
}

final class PermissionDeniedDetected extends NotificationsEvent {
  const PermissionDeniedDetected();
}

final class SubscriptionIdleReached extends NotificationsEvent {
  const SubscriptionIdleReached();
}

final class SyncSubscriptionsRequested extends NotificationsEvent {
  const SyncSubscriptionsRequested();
}

final class SubscriptionRegistered extends NotificationsEvent {
  const SubscriptionRegistered();
}

final class SubscriptionSyncFailed extends NotificationsEvent {
  const SubscriptionSyncFailed();
}

final class UnregisterSubscriptionRequested extends NotificationsEvent {
  const UnregisterSubscriptionRequested();
}

final class OpenChatIntentReceived extends NotificationsEvent {
  const OpenChatIntentReceived({
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

/// Macchina notifications — interprete statechart client.
///
/// Ingresso open chat: [NotificationsAdapters] da [PushNotificationListener].
/// Sync subscription: eventi da [PushCoordinator.syncPushSubscriptions].
class NotificationsMachine {
  NotificationsMachine({this._effects});

  final NotificationsEffects? _effects;

  NotificationsSubscriptionState subscriptionState =
      NotificationsSubscriptionState.idle;
  NotificationsOpenChatState openChatState = NotificationsOpenChatState.idle;

  final List<({String recipientUserId, String peerProfileId})> _pendingWhileBusy =
      [];
  bool _openChatChainBusy = false;

  void send(NotificationsEvent event) {
    switch (event) {
      case PushUnsupportedDetected():
        subscriptionState = NotificationsSubscriptionState.pushUnsupported;
      case PermissionDeniedDetected():
        subscriptionState = NotificationsSubscriptionState.permissionDenied;
      case SubscriptionIdleReached():
        if (subscriptionState != NotificationsSubscriptionState.pushUnsupported &&
            subscriptionState !=
                NotificationsSubscriptionState.permissionDenied) {
          subscriptionState = NotificationsSubscriptionState.idle;
        }
      case SyncSubscriptionsRequested():
        if (subscriptionState == NotificationsSubscriptionState.pushUnsupported ||
            subscriptionState == NotificationsSubscriptionState.permissionDenied) {
          return;
        }
        subscriptionState = NotificationsSubscriptionState.syncing;
      case SubscriptionRegistered():
        subscriptionState = NotificationsSubscriptionState.active;
      case SubscriptionSyncFailed():
        if (subscriptionState == NotificationsSubscriptionState.syncing) {
          subscriptionState = NotificationsSubscriptionState.idle;
        }
      case UnregisterSubscriptionRequested():
        if (subscriptionState == NotificationsSubscriptionState.active) {
          subscriptionState = NotificationsSubscriptionState.idle;
        }
      case OpenChatIntentReceived():
        _handleOpenChatIntent(event);
      case SessionBecameReady():
        _drainQueuedOpenChat();
    }
  }

  void _handleOpenChatIntent(OpenChatIntentReceived event) {
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
