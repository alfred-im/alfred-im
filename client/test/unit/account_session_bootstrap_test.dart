// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/services/account_session.dart';

void main() {
  group('AccountSession bootstrap client', () {
    test('createBootstrapClient is constructible', () {
      final client = AccountSession.createBootstrapClient();
      addTearDown(client.dispose);
      expect(client.auth.currentSession, isNull);
    });

    // Regressione documentata (2026-06-29, riproduzione curl su GoTrue live):
    // 1. signIn → refresh_token RT
    // 2. setSession(RT) sul client dedicato → OK
    // 3. POST /logout con access_token del bootstrap → 204
    // 4. refresh RT → error_code refresh_token_not_found
    // Il finally con bootstrap.auth.signOut() revocava la sessione appena adottata.
    //
    // Recupero password: bootstrap PKCE senza pkceAsyncStorage → crash client.
    // Fix: EphemeralPkceStorage (vedi test/live/password_reset_live_test.dart).
    test('resetPassword via bootstrap does not crash PKCE (has pkce storage)', () async {
      final client = AccountSession.createBootstrapClient();
      addTearDown(client.dispose);
      Object? caught;
      try {
        await client.auth.resetPasswordForEmail(
          'agadriel.sexpositive+alfredagent1@gmail.com',
          redirectTo: 'https://alfred-im.github.io/alfred-im/',
        );
      } catch (e) {
        caught = e;
      }
      if (caught == null) return;
      final label = caught.toString().toLowerCase();
      expect(
        label,
        isNot(anyOf(contains('null'), contains('asyncstorage'))),
        reason: 'bootstrap PKCE senza storage crasha: $caught',
      );
    }, tags: ['live']);
  });
}
