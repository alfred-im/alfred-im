// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyAuthError(Object e) {
  if (e is AuthException) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid refresh') ||
        msg.contains('refresh token not found') ||
        msg.contains('session expired') ||
        msg.contains('token has expired')) {
      return 'Sessione scaduta per questo account. Accedi di nuovo.';
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
    if (msg.contains('conferma l\'email')) {
      return e.message;
    }
    return e.message;
  }
  return e.toString();
}
