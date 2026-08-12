// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/peer_relationship.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
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

  /// Flag inbox sul peer in chat aperta, se coincide con [profileId].
  static PeerRelationship? peerFlagsForProfile(
    BuildContext context,
    String profileId,
  ) {
    try {
      final peer = context.read<AuthController>().activePeer;
      if (peer?.profileId != profileId) return null;
      return peer?.relationship;
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Solo controller — verità dopo mutazione e reload.
  static PeerRelationship relationshipFromControllers(
    BuildContext context, {
    required String profileId,
  }) {
    return PeerRelationship(
      inContacts: isInContacts(context, profileId),
      isAllowed: isAllowed(context, profileId),
    );
  }

  /// Lettura UI: controller **oppure** flag sul peer attivo (cache vuota dopo switch).
  static PeerRelationship relationshipForPeer(
    BuildContext context, {
    required String profileId,
    PeerRelationship? peerFlags,
  }) {
    final flags = peerFlags ?? peerFlagsForProfile(context, profileId);
    return PeerRelationship(
      inContacts: isInContacts(context, profileId) ||
          (flags?.inContacts ?? false),
      isAllowed:
          isAllowed(context, profileId) || (flags?.isAllowed ?? false),
    );
  }

  /// Dopo ogni mutazione: allinea [AuthController.activePeer] ai controller.
  static void syncActivePeerRelationship(
    BuildContext context, {
    required String profileId,
  }) {
    try {
      final auth = context.read<AuthController>();
      final peer = auth.activePeer;
      if (peer?.profileId != profileId) return;
      auth.patchActivePeer(
        peer!.withRelationship(
          relationshipFromControllers(context, profileId: profileId),
        ),
      );
    } on ProviderNotFoundException {
      // Profilo aperto senza AuthController (test / contesto isolato).
    }
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
    } else {
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

    if (!context.mounted) return;
    syncActivePeerRelationship(context, profileId: profileId);
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
    } else {
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

    if (!context.mounted) return;
    syncActivePeerRelationship(context, profileId: profileId);
  }

  static void showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}
