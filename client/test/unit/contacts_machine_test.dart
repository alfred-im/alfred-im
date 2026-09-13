// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/contacts/contacts_effects.dart';
import 'package:alfred_client/machines/contacts/contacts_machine.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingContactsEffects implements ContactsEffects {
  int loadCount = 0;
  int addByAddressCount = 0;
  String? lastAddress;

  @override
  Future<void> loadContacts() async => loadCount++;

  @override
  Future<void> addByAddress(String address) async {
    addByAddressCount++;
    lastAddress = address;
  }

  @override
  Future<void> removeByAddress(String address) async {}
}

void main() {
  test('AddContactByAddress adds and reloads', () async {
    final effects = _RecordingContactsEffects();
    final machine = ContactsMachine(effects);
    await machine.send(const AddContactByAddress('alice'));
    expect(effects.addByAddressCount, 1);
    expect(effects.lastAddress, 'alice');
    expect(effects.loadCount, 1);
  });
}
