// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../coordinators/profile_coordinator.dart';
import '../models/profile.dart';
import '../services/profile_avatar_service.dart';
import '../services/profile_service.dart';

/// Facade UI profilo — orchestrazione in [ProfileCoordinator].
class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.userId,
    required ProfileService profileService,
    required ProfileAvatarService avatarService,
  }) {
    _coordinator = ProfileCoordinator(
      userId: userId,
      profileService: profileService,
      avatarService: avatarService,
      onStateChanged: notifyListeners,
    );
  }

  final String userId;
  late final ProfileCoordinator _coordinator;

  bool get isSaving => _coordinator.isSaving;

  bool get isUploadingAvatar => _coordinator.isUploadingAvatar;

  String? get error => _coordinator.error;

  Future<UserProfile> save({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
  }) =>
      _coordinator.save(
        displayName: displayName,
        bio: bio,
        pronouns: pronouns,
        avatarUrl: avatarUrl,
      );

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) =>
      _coordinator.uploadAvatar(
        bytes: bytes,
        extension: extension,
        contentType: contentType,
      );
}
