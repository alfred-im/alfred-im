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

  static String _normalizeAddress(String address) =>
      address.trim().toLowerCase();

  static String? addressForProfile(ProfileSummary profile) =>
      profile.address ?? profile.username;

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

  static bool isInContacts(BuildContext context, String peerAddress) {
    return context
            .read<ContactsController?>()
            ?.contactForAddress(_normalizeAddress(peerAddress)) !=
        null;
  }

  static bool isAllowed(BuildContext context, String peerAddress) {
    return context
            .read<ReceptionAllowlistController?>()
            ?.isAddressAllowed(_normalizeAddress(peerAddress)) ??
        false;
  }

  /// Flag inbox sul peer in chat aperta, se coincide con [peerAddress].
  static PeerRelationship? peerFlagsForAddress(
    BuildContext context,
    String peerAddress,
  ) {
    try {
      final peer = context.read<AuthController>().activePeer;
      if (peer?.peerAddress != _normalizeAddress(peerAddress)) return null;
      return peer?.relationship;
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Solo controller — verità dopo mutazione e reload.
  static PeerRelationship relationshipFromControllers(
    BuildContext context, {
    required String peerAddress,
  }) {
    final normalized = _normalizeAddress(peerAddress);
    return PeerRelationship(
      inContacts: isInContacts(context, normalized),
      isAllowed: isAllowed(context, normalized),
    );
  }

  /// Lettura UI: controller **oppure** flag sul peer attivo (cache vuota dopo switch).
  static PeerRelationship relationshipForPeer(
    BuildContext context, {
    required String peerAddress,
    PeerRelationship? peerFlags,
  }) {
    final normalized = _normalizeAddress(peerAddress);
    final flags = peerFlags ?? peerFlagsForAddress(context, normalized);
    return PeerRelationship(
      inContacts:
          isInContacts(context, normalized) || (flags?.inContacts ?? false),
      isAllowed:
          isAllowed(context, normalized) || (flags?.isAllowed ?? false),
    );
  }

  /// Dopo ogni mutazione: allinea [AuthController.activePeer] ai controller.
  static void syncActivePeerRelationship(
    BuildContext context, {
    required String peerAddress,
  }) {
    try {
      final auth = context.read<AuthController>();
      final peer = auth.activePeer;
      if (peer?.peerAddress != _normalizeAddress(peerAddress)) return;
      auth.patchActivePeer(
        peer!.withRelationship(
          relationshipFromControllers(context, peerAddress: peerAddress),
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
    required String peerAddress,
    required bool inRubrica,
    PeerRelationship? peerFlags,
  }) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null) return;

    await contacts.ensureLoaded();
    if (!context.mounted) return;

    final normalized = _normalizeAddress(peerAddress);
    if (inRubrica) {
      await contacts.removeByAddress(normalized);
    } else {
      final relationship = relationshipForPeer(
        context,
        peerAddress: normalized,
        peerFlags: peerFlags,
      );
      await _addIdempotent(
        alreadyPresent: relationship.inContacts,
        add: () => contacts.addByAddress(normalized),
        reload: contacts.load,
      );
    }

    if (!context.mounted) return;
    syncActivePeerRelationship(context, peerAddress: normalized);
  }

  static Future<void> setAllowed({
    required BuildContext context,
    required String peerAddress,
    required bool value,
    PeerRelationship? peerFlags,
  }) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null) return;

    await allowlist.ensureLoaded();
    if (!context.mounted) return;

    final normalized = _normalizeAddress(peerAddress);
    if (!value) {
      await allowlist.removeByAddress(normalized);
    } else {
      final relationship = relationshipForPeer(
        context,
        peerAddress: normalized,
        peerFlags: peerFlags,
      );
      await _addIdempotent(
        alreadyPresent: relationship.isAllowed,
        add: () => allowlist.addAddress(normalized),
        reload: allowlist.load,
      );
    }

    if (!context.mounted) return;
    syncActivePeerRelationship(context, peerAddress: normalized);
  }

  static void showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}
