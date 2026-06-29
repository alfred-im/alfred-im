import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/services/account_session.dart';

void main() {
  group('AccountSession local logout storage', () {
    test('authStorageKey scopes GoTrue persistence per user', () {
      expect(
        AccountSession.authStorageKey('abc-123'),
        'alfred_auth_abc-123',
      );
    });
  });
}
