// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../providers/auth_controller.dart';
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
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.sessionReady) {
      if (kIsWeb) {
        PushPlatform.persistPendingOpenChat(intent.conversation);
      }
      return;
    }

    final conversation = intent.conversation;

    if (!auth.accountManager.hasOpenAccount(conversation.ownerUserId)) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final focused = await auth.focusAccountForPushNotification(
      conversation.ownerUserId,
    );
    if (!focused || !mounted) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final session = auth.focusedSession;
    if (session == null || session.userId != conversation.ownerUserId) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    // Dopo il focus, il peer è in inbox (list_inbox) — non fare SELECT diretta su
    // profiles (RLS / permessi variabili tra ambienti).
    ChatPeer? peer;
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) return;
      final liveSession = auth.focusedSession;
      if (liveSession == null ||
          liveSession.userId != conversation.ownerUserId) {
        break;
      }

      peer = liveSession.inboxController.findByProfileId(
        conversation.peerProfileId,
      );
      if (peer != null && peer.profileId != liveSession.userId) {
        break;
      }

      try {
        final summary = await liveSession.profileService.findById(
          conversation.peerProfileId,
        );
        if (summary != null && summary.id != liveSession.userId) {
          peer = ChatPeer(profile: summary);
          break;
        }
      } catch (_) {
        // Inbox o profilo non ancora pronti (RLS / rete).
      }

      peer = null;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (peer == null) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final peerToOpen = peer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthController>().openConversation(peerToOpen);
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
