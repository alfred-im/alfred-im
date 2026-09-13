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
  bool isLoading = false;
  String? error;
}

/// Orchestrazione load, filtro e CRUD allow list reception.
class ReceptionCoordinator {
  ReceptionCoordinator({
    required this._focusUserId,
    this._focusAccountAddress,
    required this._allowlistService,
    required this._onStateChanged,
  }) {
    _machine = ReceptionMachine(
      _LiveReceptionEffects._(this),
      focusUserId: _focusUserId,
      focusAccountAddress: _focusAccountAddress,
    );
  }

  final String _focusUserId;
  final String? _focusAccountAddress;
  final ReceptionAllowlistService _allowlistService;
  final void Function() _onStateChanged;
  late final ReceptionMachine _machine;
  final ReceptionState state = ReceptionState();

  List<AllowedPerson> get filteredAllowedPeople => filterByQuery(
        state.allowedPeople,
        _machine.searchQuery,
        (person) => person.displayName,
      );

  Set<String> get allowedAddresses =>
      state.allowedPeople.map((p) => p.allowedAddress).toSet();

  void setSearchQuery(String value) {
    unawaited(_machine.send(SetSearchQuery(value)));
    _syncLoadingFromMachine();
    _notify();
  }

  Future<void> load() => _machine.send(const LoadAllowlist());

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return _allowlistService.searchProfiles(query);
  }

  Future<void> addAddress(String address) {
    return _machine.send(AddAllowedAddress(address));
  }

  Future<void> addProfile(ProfileSummary profile) {
    return _machine.send(AddAllowedProfile(profile));
  }

  Future<void> remove(AllowedPerson person) {
    return _machine.send(RemoveAllowedPerson(person));
  }

  Future<void> removeByAddress(String address) {
    return _machine.send(RemoveAllowedByAddress(address));
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
          await _c._allowlistService.fetchAllowedPeople(_c._focusUserId);
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
  bool isAddressAllowed(String address) {
    return _c.allowedAddresses.contains(address.trim().toLowerCase());
  }

  @override
  Future<void> addAllowedAddress(String address) async {
    await _c._allowlistService.addAllowedAddress(
      archiveUserId: _c._focusUserId,
      address: address,
    );
  }

  @override
  Future<void> removeAllowedPerson(AllowedPerson person) async {
    await _c._allowlistService.removeAllowedPerson(person.entryId);
  }

  @override
  Future<void> removeByAddress(String address) async {
    final normalized = address.trim().toLowerCase();
    AllowedPerson? person;
    for (final entry in _c.state.allowedPeople) {
      if (entry.allowedAddress == normalized) {
        person = entry;
        break;
      }
    }
    if (person == null) return;
    await removeAllowedPerson(person);
  }
}
