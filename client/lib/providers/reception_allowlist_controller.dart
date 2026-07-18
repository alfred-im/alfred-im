// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../coordinators/reception_coordinator.dart';
import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import '../services/reception_allowlist_service.dart';

/// Facade UI allow list — orchestrazione in [ReceptionCoordinator].
class ReceptionAllowlistController extends ChangeNotifier {
  ReceptionAllowlistController({
    required this.ownerId,
    required ReceptionAllowlistService allowlistService,
  }) {
    _coordinator = ReceptionCoordinator(
      ownerId: ownerId,
      allowlistService: allowlistService,
      onStateChanged: notifyListeners,
    );
  }

  final String ownerId;
  late final ReceptionCoordinator _coordinator;

  List<AllowedPerson> get allowedPeople => _coordinator.state.allowedPeople;

  bool get isLoading => _coordinator.state.isLoading;

  String? get error => _coordinator.state.error;

  List<AllowedPerson> get filteredAllowedPeople =>
      _coordinator.filteredAllowedPeople;

  Set<String> get allowedProfileIds => _coordinator.allowedProfileIds;

  void setSearchQuery(String value) => _coordinator.setSearchQuery(value);

  Future<void> load() => _coordinator.load();

  Future<List<ProfileSummary>> searchProfiles(String query) =>
      _coordinator.searchProfiles(query);

  Future<void> addProfile(ProfileSummary profile) =>
      _coordinator.addProfile(profile);

  Future<void> remove(AllowedPerson person) => _coordinator.remove(person);

  Future<void> removeByProfileId(String profileId) =>
      _coordinator.removeByProfileId(profileId);
}
