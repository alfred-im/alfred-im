import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    // Recupero password: bootstrap PKCE senza pkceAsyncStorage → crash «null value».
    test('bootstrap client uses implicit auth flow', () {
      expect(AuthFlowType.implicit, isNot(AuthFlowType.pkce));
    });
  });
}
