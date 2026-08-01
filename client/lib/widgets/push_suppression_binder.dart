// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/push_sync_scope.dart';
import '../providers/auth_controller.dart';
import '../utils/push_media_sync_guard.dart';
import '../utils/push_permission_flow.dart';
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
  String? _lastNotificationPermission;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      PushPlatform.ensureMessageHook();
      _lastNotificationPermission = PushPlatform.notificationPermission;
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
      unawaited(_syncPushOnResume());
    }
  }

  Future<void> _syncPushOnResume() async {
    if (!kIsWeb || PushMediaSyncGuard.isActive) return;

    final auth = context.read<AuthController>();
    final permission = PushPlatform.notificationPermission;
    final justGranted = notificationPermissionJustGranted(
      previous: _lastNotificationPermission,
      current: permission,
    );
    _lastNotificationPermission = permission;

    if (justGranted) {
      await auth.syncPushSubscriptions(
        scope: PushSyncScope.allOpenAccounts,
        reason: PushSyncReason.permissionGranted,
      );
      return;
    }

    await auth.syncPushSubscriptions(
      scope: PushSyncScope.focusedAccount,
      reason: PushSyncReason.appResumed,
    );
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
