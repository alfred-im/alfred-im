import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/profile_service.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.userId,
    ProfileService? profileService,
  }) : _profileService = profileService ?? ProfileService();

  final String userId;
  final ProfileService _profileService;

  bool isSaving = false;
  String? error;

  Future<UserProfile> save({
    required String displayName,
    String? bio,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      return await _profileService.updateProfile(
        userId: userId,
        displayName: displayName,
        bio: bio,
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
