// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);

  group('Contact.internalProfileSummary', () {
    test('returns summary for internal contact with linked profile', () {
      final contact = Contact(
        id: 'c1',
        ownerId: 'owner',
        protocol: ContactProtocol.internal,
        linkedProfileId: 'p1',
        displayName: 'Alice',
        avatarUrl: 'https://cdn.example/a.png',
        createdAt: createdAt,
      );

      expect(contact.internalProfileSummary, isNotNull);
      expect(contact.internalProfileSummary!.id, 'p1');
      expect(contact.internalProfileSummary!.displayName, 'Alice');
      expect(contact.internalProfileSummary!.avatarUrl, 'https://cdn.example/a.png');
    });

    test('returns null for external contact', () {
      final contact = Contact(
        id: 'c2',
        ownerId: 'owner',
        protocol: ContactProtocol.xmpp,
        externalAddress: 'a@b.c',
        displayName: 'Bob',
        createdAt: createdAt,
      );

      expect(contact.internalProfileSummary, isNull);
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
