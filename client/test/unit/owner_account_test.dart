// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/models/instance_stats.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProfileKind.owner parses wire value', () {
    expect(ProfileKind.fromString('owner'), ProfileKind.owner);
    expect(ProfileKind.owner.wireValue, 'owner');
  });

  test('ProfileSummary.isOwner and hasPersonalInbox', () {
    const owner = ProfileSummary(
      id: 'id',
      displayName: 'Admin',
      profileKind: ProfileKind.owner,
    );
    expect(owner.isOwner, isTrue);
    expect(owner.hasPersonalInbox, isTrue);
    expect(owner.isGroup, isFalse);
  });

  test('InstanceStats.fromJson reads counters', () {
    final stats = InstanceStats.fromJson({
      'total_user_accounts': 12,
      'total_groups': 2,
      'disabled_accounts': 1,
      'total_messages': 500,
      'messages_last_7_days': 40,
      'active_accounts_30d': 8,
    });
    expect(stats.totalUserAccounts, 12);
    expect(stats.messagesLast7Days, 40);
    expect(stats.activeAccounts30d, 8);
  });
}
