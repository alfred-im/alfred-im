// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../machines/notifications/notifications_machine.dart';
import '../providers/auth_controller.dart';
import '../utils/diagnostic_log.dart';
import '../utils/push_platform.dart';

/// Gestisce tap notifica push → [NotificationsMachine] → [ExternalIntentAdapter].
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

  @override
  void initState() {
    super.initState();
    final debugStream = widget.debugOpenChatIntents;
    if (debugStream != null) {
      _sub = debugStream.listen(_dispatchOpenChatIntent);
      return;
    }
    if (kIsWeb) {
      PushPlatform.ensureMessageHook();
      _sub = PushPlatform.openChatIntents.listen(_dispatchOpenChatIntent);
    }
  }

  void _dispatchOpenChatIntent(PushOpenChatIntent intent) {
    if (!mounted) {
      diagLogFail(
        'push',
        'handler.open_chat',
        'unmounted',
        data: {'recipientUserId': intent.conversation.ownerUserId},
      );
      return;
    }
    final auth = context.read<AuthController>();
    final conversation = intent.conversation;
    diagLog(
      'push',
      'handler.enqueue',
      data: {
        'recipientUserId': conversation.ownerUserId,
        'peerProfileId': conversation.peerProfileId,
      },
    );
    auth.notificationsAdapters.onOpenChatIntent(
      conversation: conversation,
      sessionReady: auth.sessionReady,
      hasOpenAccount: auth.accountManager.hasOpenAccount(conversation.ownerUserId),
    );
  }

  /// Test: esegue il percorso tap push senza dipendere dal timing dello stream.
  @visibleForTesting
  Future<void> processOpenChatForTest(PushOpenChatIntent intent) async {
    _dispatchOpenChatIntent(intent);
    final auth = context.read<AuthController>();
    while (auth.notificationsMachine.openChatState !=
        NotificationsOpenChatState.idle) {
      await Future<void>.delayed(Duration.zero);
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
