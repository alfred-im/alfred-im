// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/contacts_controller.dart';
import 'package:alfred_client/providers/reception_allowlist_controller.dart';
import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/services/contact_service.dart';
import 'package:alfred_client/services/reception_allowlist_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_messaging_services.dart';

bool contactsKeepPrevious(ContactsController previous, AccountSession session) {
  return previous.ownerId == session.userId &&
      previous.sessionEpoch == session.epoch;
}

bool allowlistKeepPrevious(
  ReceptionAllowlistController previous,
  AccountSession session,
) {
  return previous.ownerId == session.userId &&
      previous.sessionEpoch == session.epoch;
}

void main() {
  test('focusScoped keepPrevious invalida controller su nuovo session epoch',
      () async {
    final client = createTestSupabaseClient();
    final sessionV1 = await AccountSession.createForTest(
      profile: const ProfileSummary(
        id: 'owner-id',
        username: 'owner',
        displayName: 'Owner',
      ),
      client: client,
    );
    final sessionV2 = await AccountSession.createForTest(
      profile: sessionV1.profile,
      client: client,
    );

    expect(sessionV1.userId, sessionV2.userId);
    expect(sessionV1.epoch, isNot(sessionV2.epoch));

    final contacts = ContactsController(
      ownerId: sessionV1.userId,
      sessionEpoch: sessionV1.epoch,
      contactService: ContactService(client),
    );
    final allowlist = ReceptionAllowlistController(
      ownerId: sessionV1.userId,
      sessionEpoch: sessionV1.epoch,
      allowlistService: ReceptionAllowlistService(client),
    );

    expect(contactsKeepPrevious(contacts, sessionV1), isTrue);
    expect(contactsKeepPrevious(contacts, sessionV2), isFalse);
    expect(allowlistKeepPrevious(allowlist, sessionV1), isTrue);
    expect(allowlistKeepPrevious(allowlist, sessionV2), isFalse);
  });
}
