// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/profile_summary.dart';

/// Effetti shareable-link → navigation, profilo, lookup.
abstract class ShareableLinkEffects {
  bool get sessionReady;
  bool get hasOpenAccounts;
  String? get focusedUserId;
  String? get focusedAccountAddress;

  Future<ProfileSummary?> findProfileByUsername(String localUsername);

  Future<bool> openSharedChat({
    required String accountUserId,
    required String peerAddress,
  });

  Future<void> showProfileOverlay(ProfileSummary profile);
}
