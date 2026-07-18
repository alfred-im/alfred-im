// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../utils/shareable_link.dart';
import '../utils/shareable_link_platform.dart';
import '../widgets/peer_profile_overlay.dart';

/// Gestisce destinazione da fragment `#` e stato risorsa non trovata.
class ShareableLinkController extends ChangeNotifier {
  ShareableLinkController() {
    applyFragment(readShareableFragment());
  }

  ShareableLinkTarget? _target;
  bool notFound = false;
  bool _handling = false;

  ShareableLinkTarget? get target => _target;
  bool get isHandling => _handling;

  void applyFragment(String? fragment) {
    final parsed = parseShareableFragment(fragment);
    if (parsed == null) {
      if (_target != null || notFound) {
        _target = null;
        notFound = false;
        notifyListeners();
      }
      return;
    }

    if (_target?.address == parsed.address && _target?.kind == parsed.kind) {
      return;
    }

    _target = parsed;
    notFound = false;
    notifyListeners();
  }

  void clearNotFound() {
    if (!notFound) return;
    notFound = false;
    _target = null;
    notifyListeners();
  }

  Future<void> handleIfReady(BuildContext context) async {
    if (_target == null || _handling || notFound) return;

    final auth = context.read<AuthController>();
    if (!auth.sessionReady || !auth.hasOpenAccounts) return;

    final session = auth.focusedSession;
    if (session == null) return;

    _handling = true;
    notifyListeners();

    try {
      final resolution = resolveShareableAddress(_target!.address);
      if (resolution == null) {
        notFound = true;
        return;
      }

      final profile =
          await session.profileService.findByUsername(resolution.localUsername);
      if (profile == null) {
        notFound = true;
        return;
      }

      if (profile.id == auth.userId) {
        _target = null;
        return;
      }

      if (!context.mounted) return;

      if (_target!.kind == ShareableLinkKind.chat) {
        await auth.openConversationOnAccount(
          accountUserId: auth.userId!,
          peerProfileId: profile.id,
        );
      } else {
        await showPeerProfileOverlay(context, profile);
      }

      _target = null;
      notFound = false;
    } finally {
      _handling = false;
      notifyListeners();
    }
  }

  void dismissNotFound() {
    clearShareableFragment();
    clearNotFound();
  }
}
