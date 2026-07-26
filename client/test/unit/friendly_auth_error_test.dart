// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/utils/conversation_session_access.dart';
import 'package:alfred_client/utils/friendly_auth_error.dart';

void main() {
  group('friendly_auth_error', () {
    test('isPermanentAuthFailure riconosce refresh invalido', () {
      expect(
        isPermanentAuthFailure(
          const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
        ),
        isTrue,
      );
    });

    test('friendlyAuthError unifica messaggio sessione scaduta', () {
      expect(
        friendlyAuthError(
          const AuthException('session expired'),
        ),
        conversationSessionExpiredMessage,
      );
    });
  });
}
