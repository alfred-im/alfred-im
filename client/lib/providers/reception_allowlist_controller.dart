import 'package:flutter/foundation.dart';

import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import '../services/reception_allowlist_service.dart';
import '../utils/list_filter.dart';

class ReceptionAllowlistController extends ChangeNotifier {
  ReceptionAllowlistController({
    required this.ownerId,
    required this.allowlistService,
  }) {
    load();
  }

  final String ownerId;
  final ReceptionAllowlistService allowlistService;

  List<AllowedPerson> allowedPeople = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  List<AllowedPerson> get filteredAllowedPeople => filterByQuery(
        allowedPeople,
        _searchQuery,
        (person) => person.displayName,
      );

  Set<String> get allowedProfileIds =>
      allowedPeople.map((p) => p.profile.id).toSet();

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  Future<void> load() async {
    try {
      allowedPeople = await allowlistService.fetchAllowedPeople(ownerId);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ProfileSummary>> searchProfiles(String query) {
    return allowlistService.searchProfiles(query);
  }

  Future<void> addProfile(ProfileSummary profile) async {
    if (profile.id == ownerId) return;
    if (allowedProfileIds.contains(profile.id)) return;

    await allowlistService.addAllowedProfile(
      ownerId: ownerId,
      profile: profile,
    );
    await load();
  }

  Future<void> remove(AllowedPerson person) async {
    await allowlistService.removeAllowedPerson(person.entryId);
    await load();
  }
}
