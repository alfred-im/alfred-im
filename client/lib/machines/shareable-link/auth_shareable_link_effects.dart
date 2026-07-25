// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../models/profile_summary.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/peer_profile_overlay.dart';
import 'shareable_link_effects.dart';

/// Effetti shareable-link → [AuthController] / navigation.
class AuthShareableLinkEffects implements ShareableLinkEffects {
  AuthShareableLinkEffects(this._auth, this._contextAccessor);

  final AuthController _auth;
  final BuildContext Function() _contextAccessor;

  @override
  bool get sessionReady => _auth.sessionReady;

  @override
  bool get hasOpenAccounts => _auth.hasOpenAccounts;

  @override
  String? get focusedUserId => _auth.focusedSession?.userId;

  @override
  Future<ProfileSummary?> findProfileByUsername(String localUsername) {
    final session = _auth.focusedSession;
    if (session == null) return Future.value();
    return session.profileService.findByUsername(localUsername);
  }

  @override
  Future<bool> openSharedChat({
    required String accountUserId,
    required String peerProfileId,
  }) {
    return _auth.openConversationFromShareableLink(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
    );
  }

  @override
  Future<void> showProfileOverlay(ProfileSummary profile) async {
    final context = _contextAccessor();
    if (!context.mounted) return;
    await showPeerProfileOverlay(context, profile);
  }
}
