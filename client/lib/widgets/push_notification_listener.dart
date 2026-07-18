// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/auth_controller.dart';
import '../utils/diagnostic_log.dart';
import '../utils/push_platform.dart';

/// Gestisce tap notifica push → focus account + apertura chat.
class PushNotificationListener extends StatefulWidget {
  const PushNotificationListener({
    super.key,
    required this.child,
    @visibleForTesting this.debugOpenChatIntents,
  });

  final Widget child;

  @visibleForTesting
  final Stream<PushOpenChatIntent>? debugOpenChatIntents;

  @override
  State<PushNotificationListener> createState() =>
      PushNotificationListenerState();
}

class PushNotificationListenerState extends State<PushNotificationListener> {
  StreamSubscription<PushOpenChatIntent>? _sub;
  bool _drainScheduled = false;
  Future<void> _openChatChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final debugStream = widget.debugOpenChatIntents;
    if (debugStream != null) {
      _sub = debugStream.listen(_enqueueOpenChat);
      return;
    }
    if (kIsWeb) {
      PushPlatform.ensureMessageHook();
      _sub = PushPlatform.openChatIntents.listen(_enqueueOpenChat);
    }
  }

  void _enqueueOpenChat(PushOpenChatIntent intent) {
    diagLog(
      'push',
      'handler.enqueue',
      data: {
        'recipientUserId': intent.conversation.ownerUserId,
        'peerProfileId': intent.conversation.peerProfileId,
      },
    );
    _openChatChain = _openChatChain.then((_) async {
      await _handleOpenChat(intent);
    });
  }

  /// Test: esegue il percorso tap push senza dipendere dal timing dello stream.
  @visibleForTesting
  Future<void> processOpenChatForTest(PushOpenChatIntent intent) async {
    await _handleOpenChat(intent);
  }

  Future<void> _handleOpenChat(PushOpenChatIntent intent) async {
    final conversation = intent.conversation;
    if (!mounted) {
      diagLogFail(
        'push',
        'handler.open_chat',
        'unmounted',
        data: {'recipientUserId': conversation.ownerUserId},
      );
      return;
    }
    final auth = context.read<AuthController>();
    if (!auth.sessionReady) {
      diagLogFail('push', 'handler.open_chat', 'session_not_ready');
      if (kIsWeb) {
        PushPlatform.persistPendingOpenChat(conversation);
      }
      return;
    }

    if (!auth.accountManager.hasOpenAccount(conversation.ownerUserId)) {
      diagLogFail(
        'push',
        'handler.open_chat',
        'no_open_account',
        data: {'recipientUserId': conversation.ownerUserId},
      );
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    diagLog(
      'push',
      'handler.focus.start',
      data: {'recipientUserId': conversation.ownerUserId},
    );
    final focused = await auth.focusAccountForPushNotification(
      conversation.ownerUserId,
    );
    if (!focused || !mounted) {
      diagLogFail(
        'push',
        'handler.open_chat',
        focused ? 'unmounted_after_focus' : 'focus_failed',
        data: {'recipientUserId': conversation.ownerUserId},
      );
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final session = auth.focusedSession;
    if (session == null || session.userId != conversation.ownerUserId) {
      diagLogFail(
        'push',
        'handler.open_chat',
        'wrong_session',
        data: {
          'expected': conversation.ownerUserId,
          'actual': session?.userId,
        },
      );
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    diagLog('push', 'handler.peer_lookup.start', data: {'peerProfileId': conversation.peerProfileId});
    ChatPeer? peer;
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) {
        diagLogFail('push', 'handler.peer_lookup', 'unmounted', data: {'attempt': attempt});
        return;
      }
      final liveSession = auth.focusedSession;
      if (liveSession == null ||
          liveSession.userId != conversation.ownerUserId) {
        diagLogFail(
          'push',
          'handler.peer_lookup',
          'session_lost',
          data: {'attempt': attempt},
        );
        break;
      }

      peer = liveSession.inboxController.findByProfileId(
        conversation.peerProfileId,
      );
      if (peer != null && peer.profileId != liveSession.userId) {
        diagLog(
          'push',
          'handler.peer_lookup',
          data: {'source': 'inbox', 'attempt': attempt},
        );
        break;
      }

      try {
        final summary = await liveSession.profileService.findById(
          conversation.peerProfileId,
        );
        if (summary != null && summary.id != liveSession.userId) {
          peer = ChatPeer(profile: summary);
          diagLog(
            'push',
            'handler.peer_lookup',
            data: {'source': 'profile', 'attempt': attempt},
          );
          break;
        }
      } catch (e) {
        diagLog(
          'push',
          'handler.peer_lookup.retry',
          data: {'attempt': attempt, 'error': e.runtimeType.toString()},
        );
      }

      peer = null;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (peer == null) {
      diagLogFail(
        'push',
        'handler.open_chat',
        'peer_timeout',
        data: {'peerProfileId': conversation.peerProfileId},
      );
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final peerToOpen = peer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        diagLogFail('push', 'handler.open_chat', 'unmounted_before_open');
        return;
      }
      context.read<AuthController>().openConversation(peerToOpen);
      diagLog(
        'push',
        'handler.chat_opened',
        data: {'peerProfileId': peerToOpen.profileId},
      );
      if (kIsWeb) {
        PushPlatform.clearPendingOpenChat();
      }
    });
  }

  void _scheduleDrainPending() {
    if (!kIsWeb || _drainScheduled) return;
    final auth = context.read<AuthController>();
    if (!auth.sessionReady) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      if (!mounted) return;
      PushPlatform.tryDrainPendingOpenChat();
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();
    _scheduleDrainPending();
    return widget.child;
  }
}
