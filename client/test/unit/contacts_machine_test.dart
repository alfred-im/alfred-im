// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/machines/contacts/contacts_effects.dart';
import 'package:alfred_client/machines/contacts/contacts_machine.dart';
import 'package:alfred_client/models/contact.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingContactsEffects implements ContactsEffects {
  int loadCount = 0;
  int addInternalCount = 0;
  int addExternalCount = 0;
  int removeInternalCount = 0;
  ProfileSummary? lastInternalProfile;
  ContactProtocol? lastExternalProtocol;
  String? lastExternalAddress;
  String? lastExternalDisplayName;
  String? lastRemovedProfileId;

  @override
  Future<void> loadContacts() async {
    loadCount++;
  }

  @override
  Future<void> addInternal(ProfileSummary profile) async {
    addInternalCount++;
    lastInternalProfile = profile;
  }

  @override
  Future<void> addExternal({
    required ContactProtocol protocol,
    required String address,
    required String displayName,
  }) async {
    addExternalCount++;
    lastExternalProtocol = protocol;
    lastExternalAddress = address;
    lastExternalDisplayName = displayName;
  }

  @override
  Future<void> removeInternalByProfileId(String profileId) async {
    removeInternalCount++;
    lastRemovedProfileId = profileId;
  }
}

ProfileSummary _profile({String id = 'profile-1'}) => ProfileSummary(
      id: id,
      displayName: 'Alice',
      username: 'alice',
    );

void main() {
  group('ContactsMachine load state', () {
    test('starts loading', () {
      final machine = ContactsMachine(_RecordingContactsEffects());

      expect(machine.loadState, ContactsLoadState.loading);
      expect(machine.searchQuery, '');
    });

    test('LoadContacts → loading and calls effect', () async {
      final effects = _RecordingContactsEffects();
      final machine = ContactsMachine(effects)
        ..loadState = ContactsLoadState.ready;

      await machine.send(const LoadContacts());

      expect(machine.loadState, ContactsLoadState.loading);
      expect(effects.loadCount, 1);
    });

    test('ContactsLoaded → ready', () async {
      final machine = ContactsMachine(_RecordingContactsEffects());

      await machine.send(const ContactsLoaded());

      expect(machine.loadState, ContactsLoadState.ready);
    });

    test('ContactsLoadFailed → ready', () async {
      final machine = ContactsMachine(_RecordingContactsEffects());

      await machine.send(const ContactsLoadFailed());

      expect(machine.loadState, ContactsLoadState.ready);
    });
  });

  group('ContactsMachine search', () {
    test('SetSearchQuery updates query', () async {
      final machine = ContactsMachine(_RecordingContactsEffects());

      await machine.send(const SetSearchQuery('alice'));

      expect(machine.searchQuery, 'alice');
    });

    test('SetSearchQuery does not change load state', () async {
      final machine = ContactsMachine(_RecordingContactsEffects())
        ..loadState = ContactsLoadState.ready;

      await machine.send(const SetSearchQuery('alice'));

      expect(machine.loadState, ContactsLoadState.ready);
    });
  });

  group('ContactsMachine CRUD', () {
    test('AddInternalContact adds and reloads', () async {
      final effects = _RecordingContactsEffects();
      final machine = ContactsMachine(effects);
      final profile = _profile();

      await machine.send(AddInternalContact(profile));

      expect(effects.addInternalCount, 1);
      expect(effects.lastInternalProfile, profile);
      expect(effects.loadCount, 1);
      expect(machine.loadState, ContactsLoadState.loading);
    });

    test('AddExternalContact adds and reloads', () async {
      final effects = _RecordingContactsEffects();
      final machine = ContactsMachine(effects);

      await machine.send(
        const AddExternalContact(
          protocol: ContactProtocol.xmpp,
          address: 'alice@example.com',
          displayName: 'Alice XMPP',
        ),
      );

      expect(effects.addExternalCount, 1);
      expect(effects.lastExternalProtocol, ContactProtocol.xmpp);
      expect(effects.lastExternalAddress, 'alice@example.com');
      expect(effects.lastExternalDisplayName, 'Alice XMPP');
      expect(effects.loadCount, 1);
      expect(machine.loadState, ContactsLoadState.loading);
    });

    test('RemoveInternalContact removes and reloads', () async {
      final effects = _RecordingContactsEffects();
      final machine = ContactsMachine(effects);

      await machine.send(const RemoveInternalContact('profile-42'));

      expect(effects.removeInternalCount, 1);
      expect(effects.lastRemovedProfileId, 'profile-42');
      expect(effects.loadCount, 1);
      expect(machine.loadState, ContactsLoadState.loading);
    });
  });
}
