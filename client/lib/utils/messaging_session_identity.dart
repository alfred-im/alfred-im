// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

/// Stesso testo di [MessagesControllerEffects.sessionExpiredMessage].
const messagingSessionExpiredMessage = 'Sessione scaduta — accedi di nuovo';

/// True se il client GoTrue può eseguire RPC messaggistica per [ownerUserId] → [peerProfileId].
///
/// Invariante PROM-CONVERSATION-SCOPE-009: `auth.uid == ownerUserId` e peer distinto.
bool isMessagingIdentityAligned({
  required SupabaseClient client,
  required String ownerUserId,
  required String peerProfileId,
}) {
  final token = client.auth.currentSession?.accessToken;
  if (token == null || token.isEmpty) return false;
  final authUserId = client.auth.currentUser?.id;
  if (authUserId == null) return false;
  if (authUserId != ownerUserId) return false;
  if (peerProfileId == authUserId) return false;
  return true;
}

bool clientHasGoTrueSession(SupabaseClient client) {
  final authUserId = client.auth.currentUser?.id;
  if (authUserId != null) return true;
  final token = client.auth.currentSession?.accessToken;
  return token != null && token.isNotEmpty;
}

/// Messaggio utente per errori invio/fetch — mai `PostgrestException` grezzo in UI.
String friendlyMessagingError(Object error) {
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('cannot message yourself') ||
        message.contains('not authenticated')) {
      return messagingSessionExpiredMessage;
    }
    if (message.contains('recipient not found')) {
      return 'Destinatario non trovato.';
    }
    if (message.contains('empty message')) {
      return 'Il messaggio è vuoto.';
    }
    return error.message;
  }
  return error.toString();
}
