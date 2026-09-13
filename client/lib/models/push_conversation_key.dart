// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Chiave univoca conversazione 1:1: account destinatario + peer.
///
/// Regole: [docs/domain/notifications/invariants.md](../../docs/domain/notifications/invariants.md)
/// Formato canonico condiviso con outbound queue e scope messaggistica.
class PushConversationKey {
  const PushConversationKey({
    required this.recipientUserId,
    required this.peerAddress,
  });

  /// Account Alfred che riceve il messaggio (`recipient_user_id` nel payload).
  final String recipientUserId;

  /// Indirizzo controparte nella chat (`peerAddress` nel payload).
  final String peerAddress;

  static const separator = '|';

  String get canonicalKey => '$recipientUserId$separator$peerAddress';

  /// Chiave outbound queue / realtime — stesso formato del push.
  static String outboundQueueKey({
    required String recipientUserId,
    required String peerAddress,
  }) {
    return PushConversationKey(
      recipientUserId: recipientUserId,
      peerAddress: peerAddress,
    ).canonicalKey;
  }

  /// Tag notifica browser: conversazione + messaggio logico (dedup per device).
  String notificationTag(String logicalMessageId) {
    if (logicalMessageId.isEmpty) return canonicalKey;
    return '$canonicalKey$separator$logicalMessageId';
  }

  /// Parse da `recipient|peer` (stesso formato outbound queue / SW).
  static PushConversationKey? tryParseCanonical(String raw) {
    final parts = raw.split(separator);
    if (parts.length != 2) return null;
    final recipient = parts[0].trim();
    final peer = parts[1].trim().toLowerCase();
    if (recipient.isEmpty || peer.isEmpty || recipient == peer) return null;
    return PushConversationKey(recipientUserId: recipient, peerAddress: peer);
  }

  /// Da payload push (camelCase SW o snake_case server).
  static PushConversationKey? tryFromPayload(Map<String, dynamic> map) {
    final recipient = map['recipientUserId'] ?? map['recipient_user_id'];
    final peer = map['peerAddress'] ?? map['peer_address'];
    if (recipient is! String || peer is! String) return null;
    final normalizedPeer = peer.trim().toLowerCase();
    if (recipient.isEmpty ||
        normalizedPeer.isEmpty ||
        recipient == normalizedPeer) {
      return null;
    }
    return PushConversationKey(
      recipientUserId: recipient,
      peerAddress: normalizedPeer,
    );
  }

  /// Soppressione: push invisibile se app in foreground su questa conversazione.
  bool shouldSuppressInForeground({
    required String? focusUserId,
    required String? activePeerAddress,
    required bool appVisible,
  }) {
    if (!appVisible) return false;
    return focusUserId == recipientUserId && activePeerAddress == peerAddress;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PushConversationKey &&
          recipientUserId == other.recipientUserId &&
          peerAddress == other.peerAddress;

  @override
  int get hashCode => Object.hash(recipientUserId, peerAddress);
}
