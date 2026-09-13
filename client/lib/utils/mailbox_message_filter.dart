// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Realtime relevance for mailbox archive rows (archive_user + peer).
bool isMailboxPeerMessageRelevant({
  required Map<String, dynamic> record,
  required String currentUserId,
  required String peerAddress,
}) {
  if (!isArchiveUserRow(record: record, currentUserId: currentUserId)) {
    return false;
  }
  final recordPeer = record['peer_address'] as String?;
  if (recordPeer == null) return false;
  return recordPeer.trim().toLowerCase() == peerAddress.trim().toLowerCase();
}

bool isArchiveUserRow({
  required Map<String, dynamic> record,
  required String currentUserId,
}) {
  return record['archive_user_id'] == currentUserId;
}
