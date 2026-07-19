// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/services/account_session.dart';
import 'package:alfred_client/utils/session_scope_keys.dart';

import '../support/wiring_test_fixtures.dart';

void main() {
  test('messagesSessionKey distingue istanze sessione diverse', () async {
    final sessionA = await AccountSession.createForTest(
      profile: openAccount(userId: 'user-a', username: 'alice').profile,
    );
    final sessionB = await AccountSession.createForTest(
      profile: openAccount(userId: 'user-a', username: 'alice').profile,
    );

    expect(
      messagesSessionKey(sessionA, 'peer-b'),
      isNot(equals(messagesSessionKey(sessionB, 'peer-b'))),
    );
    expect(
      messagesSessionKey(sessionA, 'peer-b'),
      equals(messagesSessionKey(sessionA, 'peer-b')),
    );
  });

  test('groupSessionKey distingue scope e istanza sessione', () async {
    final session = await AccountSession.createForTest(
      profile: openAccount(userId: 'group-1', username: 'famiglia').profile,
    );

    expect(
      groupSessionKey(session, 'group-home'),
      isNot(equals(groupSessionKey(session, 'group-messages'))),
    );
  });
}
