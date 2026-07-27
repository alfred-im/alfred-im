// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../utils/push_platform.dart';

/// Sincronizza stato soppressione push (focus + chat attiva) verso il service worker.
class PushSuppressionBinder extends StatefulWidget {
  const PushSuppressionBinder({super.key, required this.child});

  final Widget child;

  @override
  State<PushSuppressionBinder> createState() => _PushSuppressionBinderState();
}

class _PushSuppressionBinderState extends State<PushSuppressionBinder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      PushPlatform.ensureMessageHook();
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _sync();
    if (state == AppLifecycleState.resumed) {
      unawaited(
        context.read<AuthController>().syncPushSubscriptions(onlyFocused: true),
      );
    }
  }

  void _sync() {
    if (!kIsWeb) return;
    final auth = context.read<AuthController>();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible = lifecycle == AppLifecycleState.resumed;
    final peer = auth.activePeer;
    PushPlatform.updateSuppression(
      focusUserId: auth.userId,
      activePeerProfileId: visible ? peer?.profileId : null,
      appVisible: visible,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.watch<AuthController>(),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        return child!;
      },
      child: widget.child,
    );
  }
}
