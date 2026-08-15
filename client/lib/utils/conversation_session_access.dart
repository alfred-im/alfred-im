// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

/// Regole canoniche: `docs/domain/navigation/invariants.md`
const conversationSessionExpiredMessage = 'Sessione scaduta — accedi di nuovo';

bool clientHasGoTrueSession(SupabaseClient client) {
  final authUserId = client.auth.currentUser?.id;
  if (authUserId != null) return true;
  final token = client.auth.currentSession?.accessToken;
  return token != null && token.isNotEmpty;
}

/// Invariante account — vedi dominio § Account session.
bool isAccountSessionReady({
  required SupabaseClient client,
  required String focusUserId,
}) {
  final token = client.auth.currentSession?.accessToken;
  if (token == null || token.isEmpty) return false;
  final authUserId = client.auth.currentUser?.id;
  if (authUserId == null || authUserId != focusUserId) return false;
  return true;
}

/// Invariante messaggistica — vedi dominio § Session identity.
///
/// [whenNoGoTrueSession]: harness unit senza `recoverSession` (nessun GoTrue in RAM).
bool isMessagingSessionReady({
  required SupabaseClient client,
  required String focusUserId,
  required String peerProfileId,
  bool Function()? whenNoGoTrueSession,
}) {
  if (clientHasGoTrueSession(client)) {
    if (!isAccountSessionReady(client: client, focusUserId: focusUserId)) {
      return false;
    }
    final authUserId = client.auth.currentUser?.id;
    if (authUserId == null || peerProfileId == authUserId) return false;
    return true;
  }
  if (whenNoGoTrueSession != null) return whenNoGoTrueSession();
  return true;
}

String friendlyMessagingError(Object error) {
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('cannot message yourself') ||
        message.contains('not authenticated')) {
      return conversationSessionExpiredMessage;
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
