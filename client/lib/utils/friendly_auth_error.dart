// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_session_access.dart';

String _errorMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return error.toString();
}

bool isPermanentAuthFailure(Object error) {
  final msg = _errorMessage(error).toLowerCase();
  if (msg.contains('account disabled')) return true;
  if (error is AuthException) {
    return msg.contains('invalid refresh') ||
        msg.contains('refresh token not found') ||
        msg.contains('session expired') ||
        msg.contains('token has expired');
  }
  return false;
}

String friendlyAuthError(Object e) {
  final msg = _errorMessage(e).toLowerCase();
  if (msg.contains('account disabled')) {
    return 'Account disattivato. Contatta l\'amministratore del server.';
  }
  if (e is AuthException) {
    if (isPermanentAuthFailure(e)) {
      return conversationSessionExpiredMessage;
    }
    if (msg.contains('invalid login credentials')) {
      return 'Email o password non corretti.';
    }
    if (msg.contains('username già in uso')) {
      return 'Username già in uso. Scegline un altro.';
    }
    if (msg.contains('database error saving new user')) {
      return 'Username già in uso o non valido. Scegline un altro.';
    }
    if (msg.contains('user already registered')) {
      return 'Email già registrata. Prova ad accedere.';
    }
    if (msg.contains('email rate limit exceeded') ||
        msg.contains('over_email_send_rate_limit')) {
      return 'Troppi tentativi email. Riprova tra qualche minuto.';
    }
    return e.message;
  }
  if (e is PostgrestException) {
    return e.message;
  }
  return e.toString();
}
