// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Chiave univoca conversazione 1:1: account owner + peer.
///
/// Regole: [docs/domain/notifications/invariants.md](../../docs/domain/notifications/invariants.md)
/// Formato canonico condiviso con outbound queue e scope messaggistica.
class PushConversationKey {
  const PushConversationKey({
    required this.ownerUserId,
    required this.peerProfileId,
  }) : assert(ownerUserId != peerProfileId);

  /// Account Alfred che riceve il messaggio (`recipient_user_id` nel payload).
  final String ownerUserId;

  /// Profilo controparte nella chat (`peer_profile_id` nel payload).
  final String peerProfileId;

  static const separator = '|';

  String get canonicalKey => '$ownerUserId$separator$peerProfileId';

  /// Chiave outbound queue / realtime — stesso formato del push.
  static String outboundQueueKey({
    required String ownerUserId,
    required String peerProfileId,
  }) {
    return PushConversationKey(
      ownerUserId: ownerUserId,
      peerProfileId: peerProfileId,
    ).canonicalKey;
  }

  /// Tag notifica browser: conversazione + messaggio logico (dedup per device).
  String notificationTag(String logicalMessageId) {
    if (logicalMessageId.isEmpty) return canonicalKey;
    return '$canonicalKey$separator$logicalMessageId';
  }

  /// Parse da `owner|peer` (stesso formato outbound queue / SW).
  static PushConversationKey? tryParseCanonical(String raw) {
    final parts = raw.split(separator);
    if (parts.length != 2) return null;
    final owner = parts[0].trim();
    final peer = parts[1].trim();
    if (owner.isEmpty || peer.isEmpty || owner == peer) return null;
    return PushConversationKey(ownerUserId: owner, peerProfileId: peer);
  }

  /// Da payload push (camelCase SW o snake_case server).
  static PushConversationKey? tryFromPayload(Map<String, dynamic> map) {
    final owner = map['recipientUserId'] ?? map['recipient_user_id'];
    final peer = map['peerProfileId'] ?? map['peer_profile_id'];
    if (owner is! String || peer is! String) return null;
    if (owner.isEmpty || peer.isEmpty || owner == peer) return null;
    return PushConversationKey(ownerUserId: owner, peerProfileId: peer);
  }

  /// Soppressione: push invisibile se app in foreground su questa conversazione.
  bool shouldSuppressInForeground({
    required String? focusUserId,
    required String? activePeerProfileId,
    required bool appVisible,
  }) {
    if (!appVisible) return false;
    return focusUserId == ownerUserId && activePeerProfileId == peerProfileId;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PushConversationKey &&
          ownerUserId == other.ownerUserId &&
          peerProfileId == other.peerProfileId;

  @override
  int get hashCode => Object.hash(ownerUserId, peerProfileId);
}
