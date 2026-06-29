import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/profile_avatar_service.dart';
import '../services/profile_service.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.userId,
    required this.profileService,
    required this.avatarService,
  });

  final String userId;
  final ProfileService profileService;
  final ProfileAvatarService avatarService;

  bool isSaving = false;
  bool isUploadingAvatar = false;
  String? error;

  Future<UserProfile> save({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      return await profileService.updateProfile(
        userId: userId,
        displayName: displayName,
        bio: bio,
        pronouns: pronouns,
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    isUploadingAvatar = true;
    error = null;
    notifyListeners();
    try {
      return await avatarService.uploadAvatar(
        bytes: bytes,
        userId: userId,
        extension: extension,
        contentType: contentType,
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isUploadingAvatar = false;
      notifyListeners();
    }
  }
}
