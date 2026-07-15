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
      _PushNotificationListenerState();
}

class _PushNotificationListenerState extends State<PushNotificationListener> {
  StreamSubscription<PushOpenChatIntent>? _sub;
  bool _drainScheduled = false;

  @override
  void initState() {
    super.initState();
    final debugStream = widget.debugOpenChatIntents;
    if (debugStream != null) {
      _sub = debugStream.listen(_onOpenChat);
      return;
    }
    if (kIsWeb) {
      PushPlatform.ensureMessageHook();
      _sub = PushPlatform.openChatIntents.listen(_onOpenChat);
    }
  }

  Future<void> _onOpenChat(PushOpenChatIntent intent) async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.sessionReady) return;

    final conversation = intent.conversation;

    if (!auth.accountManager.hasOpenAccount(conversation.ownerUserId)) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    final focused = await auth.focusAccountForPushNotification(
      conversation.ownerUserId,
    );
    if (!focused || !mounted) {
      if (auth.error != null && kIsWeb) {
        PushPlatform.clearPendingOpenChat();
      }
      return;
    }

    final session = auth.focusedSession;
    if (session == null || session.userId != conversation.ownerUserId) return;

    final summary = await session.profileService.findById(
      conversation.peerProfileId,
    );
    if (!mounted || summary == null) return;
    if (summary.id == session.userId) {
      if (kIsWeb) PushPlatform.clearPendingOpenChat();
      return;
    }

    auth.openConversation(ChatPeer(profile: summary));
    if (kIsWeb) {
      PushPlatform.clearPendingOpenChat();
    }
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
