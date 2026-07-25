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
  int removePersonCount = 0;
  int removeByProfileIdCount = 0;
  ProfileSummary? lastAddedProfile;
  AllowedPerson? lastRemovedPerson;
  String? lastRemovedProfileId;
  final Set<String> allowedProfileIds = {};

  @override
  Future<void> loadAllowlist() async {
    loadCount++;
  }

  @override
  bool isProfileAllowed(String profileId) {
    return allowedProfileIds.contains(profileId);
  }

  @override
  Future<void> addAllowedProfile(ProfileSummary profile) async {
    addCount++;
    lastAddedProfile = profile;
    allowedProfileIds.add(profile.id);
  }

  @override
  Future<void> removeAllowedPerson(AllowedPerson person) async {
    removePersonCount++;
    lastRemovedPerson = person;
    allowedProfileIds.remove(person.profile.id);
  }

  @override
  Future<void> removeByProfileId(String profileId) async {
    removeByProfileIdCount++;
    lastRemovedProfileId = profileId;
    allowedProfileIds.remove(profileId);
  }
}

ProfileSummary _profile({String id = 'profile-1'}) => ProfileSummary(
      id: id,
      displayName: 'Alice',
      username: 'alice',
    );

AllowedPerson _allowedPerson({String profileId = 'profile-1'}) =>
    AllowedPerson(
      entryId: 'entry-1',
      profile: _profile(id: profileId),
    );

void main() {
  const ownerId = 'owner-1';

  group('ReceptionMachine load state', () {
    test('starts loading', () {
      final machine = ReceptionMachine(
        _RecordingReceptionEffects(),
        ownerId: ownerId,
      );

      expect(machine.loadState, ReceptionLoadState.loading);
      expect(machine.searchQuery, '');
    });

    test('LoadAllowlist → loading and calls effect', () async {
      final effects = _RecordingReceptionEffects();
      final machine = ReceptionMachine(effects, ownerId: ownerId)
        ..loadState = ReceptionLoadState.ready;

      await machine.send(const LoadAllowlist());

      expect(machine.loadState, ReceptionLoadState.loading);
      expect(effects.loadCount, 1);
    });

    test('AllowlistLoaded → ready', () async {
      final machine = ReceptionMachine(
        _RecordingReceptionEffects(),
        ownerId: ownerId,
      );

      await machine.send(const AllowlistLoaded());

      expect(machine.loadState, ReceptionLoadState.ready);
    });

    test('AllowlistLoadFailed → ready', () async {
      final machine = ReceptionMachine(
        _RecordingReceptionEffects(),
        ownerId: ownerId,
      );

      await machine.send(const AllowlistLoadFailed());

      expect(machine.loadState, ReceptionLoadState.ready);
    });
  });

  group('ReceptionMachine search', () {
    test('SetAllowlistSearchQuery updates query', () async {
      final machine = ReceptionMachine(
        _RecordingReceptionEffects(),
        ownerId: ownerId,
      );

      await machine.send(const SetAllowlistSearchQuery('bob'));

      expect(machine.searchQuery, 'bob');
    });
  });

  group('ReceptionMachine add allowed profile', () {
    test('AddAllowedProfile adds and reloads', () async {
      final effects = _RecordingReceptionEffects();
      final machine = ReceptionMachine(effects, ownerId: ownerId);
      final profile = _profile(id: 'profile-2');

      await machine.send(AddAllowedProfile(profile));

      expect(effects.addCount, 1);
      expect(effects.lastAddedProfile, profile);
      expect(effects.loadCount, 1);
      expect(machine.loadState, ReceptionLoadState.loading);
    });

    test('AddAllowedProfile ignored for owner self', () async {
      final effects = _RecordingReceptionEffects();
      final machine = ReceptionMachine(effects, ownerId: ownerId);

      await machine.send(AddAllowedProfile(_profile(id: ownerId)));

      expect(effects.addCount, 0);
      expect(effects.loadCount, 0);
    });

    test('AddAllowedProfile ignored when already allowed', () async {
      final effects = _RecordingReceptionEffects()
        ..allowedProfileIds.add('profile-2');
      final machine = ReceptionMachine(effects, ownerId: ownerId);

      await machine.send(AddAllowedProfile(_profile(id: 'profile-2')));

      expect(effects.addCount, 0);
      expect(effects.loadCount, 0);
    });
  });

  group('ReceptionMachine remove allowed', () {
    test('RemoveAllowedPerson removes and reloads', () async {
      final effects = _RecordingReceptionEffects();
      final machine = ReceptionMachine(effects, ownerId: ownerId);
      final person = _allowedPerson(profileId: 'profile-3');

      await machine.send(RemoveAllowedPerson(person));

      expect(effects.removePersonCount, 1);
      expect(effects.lastRemovedPerson, person);
      expect(effects.loadCount, 1);
      expect(machine.loadState, ReceptionLoadState.loading);
    });

    test('RemoveAllowedByProfileId removes and reloads', () async {
      final effects = _RecordingReceptionEffects();
      final machine = ReceptionMachine(effects, ownerId: ownerId);

      await machine.send(const RemoveAllowedByProfileId('profile-99'));

      expect(effects.removeByProfileIdCount, 1);
      expect(effects.lastRemovedProfileId, 'profile-99');
      expect(effects.loadCount, 1);
      expect(machine.loadState, ReceptionLoadState.loading);
    });
  });
}
