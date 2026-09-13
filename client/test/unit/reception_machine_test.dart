// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/reception/reception_effects.dart';
import 'package:alfred_client/machines/reception/reception_machine.dart';
import 'package:alfred_client/models/allowed_person.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingReceptionEffects implements ReceptionEffects {
  int loadCount = 0;
  int addCount = 0;
  final Set<String> allowedAddresses = {};

  @override
  Future<void> loadAllowlist() async => loadCount++;

  @override
  bool isAddressAllowed(String address) => allowedAddresses.contains(address);

  @override
  Future<void> addAllowedAddress(String address) async {
    addCount++;
    allowedAddresses.add(address);
  }

  @override
  Future<void> removeAllowedPerson(AllowedPerson person) async {}

  @override
  Future<void> removeByAddress(String address) async {}
}

void main() {
  const focusUserId = 'focus-1';

  test('AddAllowedAddress adds and reloads', () async {
    final effects = _RecordingReceptionEffects();
    final machine = ReceptionMachine(effects, focusUserId: focusUserId);
    await machine.send(const AddAllowedAddress('bob'));
    expect(effects.addCount, 1);
    expect(effects.loadCount, 1);
  });

  test('AddAllowedProfile maps username to address', () async {
    final effects = _RecordingReceptionEffects();
    final machine = ReceptionMachine(effects, focusUserId: focusUserId);
    await machine.send(
      AddAllowedProfile(
        const ProfileSummary(
          id: 'p2',
          username: 'bob',
          address: 'bob',
          displayName: 'Bob',
        ),
      ),
    );
    expect(effects.addCount, 1);
  });
}
