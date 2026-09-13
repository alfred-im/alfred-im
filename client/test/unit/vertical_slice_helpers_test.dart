// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);

  group('Contact.address', () {
    test('stores canonical lowercase address', () {
      final contact = Contact(
        id: 'c1',
        archiveUserId: 'alice',
        address: 'bob@remote.example',
        createdAt: createdAt,
      );

      expect(contact.address, 'bob@remote.example');
    });
  });

  group('ProfileService.normalizeOptional', () {
    test('trims and nullifies empty strings', () {
      expect(ProfileService.normalizeOptional('  '), isNull);
      expect(ProfileService.normalizeOptional('  hi '), 'hi');
      expect(ProfileService.normalizeOptional(null), isNull);
    });
  });
}
