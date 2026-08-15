// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Realtime relevance for mailbox archive rows (archive_user + peer).
bool isMailboxPeerMessageRelevant({
  required Map<String, dynamic> record,
  required String currentUserId,
  required String peerProfileId,
}) {
  if (!isArchiveUserRow(record: record, currentUserId: currentUserId)) {
    return false;
  }
  return record['peer_profile_id'] == peerProfileId;
}

bool isArchiveUserRow({
  required Map<String, dynamic> record,
  required String currentUserId,
}) {
  return record['archive_user_id'] == currentUserId;
}
