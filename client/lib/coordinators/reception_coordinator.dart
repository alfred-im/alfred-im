// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import '../machines/reception/reception_effects.dart';
import '../machines/reception/reception_machine.dart';
import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import '../services/reception_allowlist_service.dart';
import '../utils/list_filter.dart';

/// Stato allow list esposto alla UI tramite [ReceptionAllowlistController].
class ReceptionState {
  List<AllowedPerson> allowedPeople = [];
  bool isLoading = true;
  String? error;
}

/// Orchestrazione load, filtro e CRUD allow list reception.
class ReceptionCoordinator {
  ReceptionCoordinator({
    required this._ownerId,
    required this._allowlistService,
    required this._onStateChanged,
  }) {
    _machine = ReceptionMachine(
      _LiveReceptionEffects._(this),
      ownerId: _ownerId,
    );
    unawaited(load());
  }

  final String _ownerId;
  final ReceptionAllowlistService _allowlistService;
  final void Function() _onStateChanged;
  late final ReceptionMachine _machine;
  final ReceptionState state = ReceptionState();

  ReceptionMachine get machine => _machine;

  List<AllowedPerson> get filteredAllowedPeople => filterByQuery(
        state.allowedPeople,
        _machine.searchQuery,
        (person) => person.displayName,
      );

  Set<String> get allowedProfileIds =>
      state.allowedPeople.map((p) => p.profile.id).toSet();

  void setSearchQuery(String value) {
    unawaited(_machine.send(SetAllowlistSearchQuery(value)));
    _syncLoadingFromMachine();
    _notify();
  }

  Future<void> load() => _machine.send(const LoadAllowlist());

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _allowlistService.searchProfiles(query);
  }

  Future<void> addProfile(ProfileSummary profile) {
    return _machine.send(AddAllowedProfile(profile));
  }

  Future<void> remove(AllowedPerson person) {
    return _machine.send(RemoveAllowedPerson(person));
  }

  Future<void> removeByProfileId(String profileId) {
    return _machine.send(RemoveAllowedByProfileId(profileId));
  }

  void _syncLoadingFromMachine() {
    state.isLoading = _machine.loadState == ReceptionLoadState.loading;
  }

  void _notify() => _onStateChanged();
}

class _LiveReceptionEffects implements ReceptionEffects {
  _LiveReceptionEffects._(this._coordinator);

  final ReceptionCoordinator _coordinator;

  ReceptionCoordinator get _c => _coordinator;

  @override
  Future<void> loadAllowlist() async {
    try {
      _c.state.allowedPeople =
          await _c._allowlistService.fetchAllowedPeople(_c._ownerId);
      _c.state.error = null;
      await _c._machine.send(const AllowlistLoaded());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const AllowlistLoadFailed());
    } finally {
      _c._syncLoadingFromMachine();
      _c._notify();
    }
  }

  @override
  void onSearchQueryChanged(String query) {}

  @override
  bool isProfileAllowed(String profileId) {
    return _c.allowedProfileIds.contains(profileId);
  }

  @override
  Future<void> addAllowedProfile(ProfileSummary profile) async {
    await _c._allowlistService.addAllowedProfile(
      ownerId: _c._ownerId,
      profile: profile,
    );
  }

  @override
  Future<void> removeAllowedPerson(AllowedPerson person) async {
    await _c._allowlistService.removeAllowedPerson(person.entryId);
  }

  @override
  Future<void> removeByProfileId(String profileId) async {
    AllowedPerson? person;
    for (final entry in _c.state.allowedPeople) {
      if (entry.profile.id == profileId) {
        person = entry;
        break;
      }
    }
    if (person == null) return;
    await removeAllowedPerson(person);
  }
}
