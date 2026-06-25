import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/auth_identity.dart';

void main() {
  group('AuthIdentity', () {
    test('normalizes username to lowercase', () {
      expect(AuthIdentity.normalizeUsername('Mario_Rossi'), 'mario_rossi');
    });

    test('validates username format', () {
      expect(AuthIdentity.isValidUsername('abc'), isTrue);
      expect(AuthIdentity.isValidUsername('ab'), isFalse);
      expect(AuthIdentity.isValidUsername('bad-name'), isFalse);
    });

    test('maps username to internal auth email', () {
      expect(
        AuthIdentity.internalAuthEmail('mario_rossi'),
        'mario_rossi@users.alfred.internal',
      );
    });

    test('extracts username from internal auth email', () {
      expect(
        AuthIdentity.usernameFromAuthEmail('mario_rossi@users.alfred.internal'),
        'mario_rossi',
      );
      expect(
        AuthIdentity.usernameFromAuthEmail('legacy@example.com'),
        isNull,
      );
    });
  });
}
