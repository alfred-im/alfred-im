import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/profile_summary.dart';

// spec: SURF-GROUP-SHELL-001, SURF-GROUP-SHELL-002
void main() {
  group('ProfileSummary group account', () {
    test('serializes profileKind in saved account json', () {
      const group = ProfileSummary(
        id: 'g1',
        displayName: 'Famiglia',
        username: 'famiglia',
        profileKind: ProfileKind.group,
      );

      final json = group.toSavedAccountJsonFields();
      expect(json['profileKind'], 'group');
    });

    test('restores profileKind from saved account json', () {
      final account = ProfileSummary.fromSavedAccountJson({
        'userId': 'g1',
        'username': 'famiglia',
        'displayName': 'Famiglia',
        'profileKind': 'group',
      });

      expect(account.isGroup, isTrue);
      expect(account.profileKind, ProfileKind.group);
    });

    test('defaults to user when profileKind missing', () {
      final account = ProfileSummary.fromSavedAccountJson({
        'userId': 'u1',
        'username': 'mario',
        'displayName': 'Mario',
      });

      expect(account.isGroup, isFalse);
    });
  });
}
