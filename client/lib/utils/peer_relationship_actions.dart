// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/peer_relationship.dart';
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

  /// Controller in RAM **oppure** flag inbox sul peer — evita label/insert falsi.
  static PeerRelationship relationshipForPeer(
    BuildContext context, {
    required String profileId,
    PeerRelationship? peerFlags,
  }) {
    return PeerRelationship(
      inContacts: isInContacts(context, profileId) ||
          (peerFlags?.inContacts ?? false),
      isAllowed:
          isAllowed(context, profileId) || (peerFlags?.isAllowed ?? false),
    );
  }

  static bool _isDuplicateKey(Object error) {
    if (error is PostgrestException) {
      return error.code == '23505';
    }
    final text = error.toString();
    return text.contains('23505') || text.contains('duplicate key');
  }

  static Future<void> _addIdempotent({
    required bool alreadyPresent,
    required Future<void> Function() add,
    required Future<void> Function() reload,
  }) async {
    if (alreadyPresent) {
      await reload();
      return;
    }
    try {
      await add();
    } catch (e) {
      if (!_isDuplicateKey(e)) rethrow;
      await reload();
    }
  }

  static Future<void> toggleRubrica({
    required BuildContext context,
    required String profileId,
    required ProfileSummary profile,
    required bool inRubrica,
    PeerRelationship? peerFlags,
  }) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null) return;

    await contacts.ensureLoaded();
    if (!context.mounted) return;
    if (inRubrica) {
      await contacts.removeInternalByProfileId(profileId);
      return;
    }

    final relationship = relationshipForPeer(
      context,
      profileId: profileId,
      peerFlags: peerFlags,
    );
    await _addIdempotent(
      alreadyPresent: relationship.inContacts,
      add: () => contacts.addInternal(profile),
      reload: contacts.load,
    );
  }

  static Future<void> setAllowed({
    required BuildContext context,
    required String profileId,
    required ProfileSummary profile,
    required bool value,
    PeerRelationship? peerFlags,
  }) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null) return;

    await allowlist.ensureLoaded();
    if (!context.mounted) return;
    if (!value) {
      await allowlist.removeByProfileId(profileId);
      return;
    }

    final relationship = relationshipForPeer(
      context,
      profileId: profileId,
      peerFlags: peerFlags,
    );
    await _addIdempotent(
      alreadyPresent: relationship.isAllowed,
      add: () => allowlist.addProfile(profile),
      reload: allowlist.load,
    );
  }

  static void showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}
