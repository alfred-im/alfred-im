// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../providers/contacts_controller.dart';
import '../providers/reception_allowlist_controller.dart';

/// Rubrica + allow list per un profilo peer — stesso flusso di [PeerProfileOverlay].
class PeerRelationshipActions {
  const PeerRelationshipActions._();

  static bool controllersReady(BuildContext context) {
    return context.read<ReceptionAllowlistController?>() != null &&
        context.read<ContactsController?>() != null;
  }

  static bool controllersSettled(BuildContext context) {
    final allowlist = context.read<ReceptionAllowlistController?>();
    final contacts = context.read<ContactsController?>();
    return allowlist != null &&
        contacts != null &&
        !allowlist.isLoading &&
        !contacts.isLoading;
  }

  static Future<void> prime(BuildContext context) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    final contacts = context.read<ContactsController?>();
    await Future.wait([
      if (allowlist != null) allowlist.ensureLoaded(),
      if (contacts != null) contacts.ensureLoaded(),
    ]);
  }

  static bool isInContacts(BuildContext context, String profileId) {
    return context
            .read<ContactsController?>()
            ?.contactForProfileId(profileId) !=
        null;
  }

  static bool isAllowed(BuildContext context, String profileId) {
    return context
            .read<ReceptionAllowlistController?>()
            ?.isProfileAllowed(profileId) ??
        false;
  }

  static Future<void> toggleRubrica({
    required BuildContext context,
    required String profileId,
    required ProfileSummary profile,
    required bool inRubrica,
  }) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null) return;

    await contacts.ensureLoaded();
    if (inRubrica) {
      await contacts.removeInternalByProfileId(profileId);
    } else {
      await contacts.addInternal(profile);
    }
  }

  static Future<void> setAllowed({
    required BuildContext context,
    required String profileId,
    required ProfileSummary profile,
    required bool value,
  }) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null) return;

    await allowlist.ensureLoaded();
    if (value) {
      await allowlist.addProfile(profile);
    } else {
      await allowlist.removeByProfileId(profileId);
    }
  }

  static void showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}
