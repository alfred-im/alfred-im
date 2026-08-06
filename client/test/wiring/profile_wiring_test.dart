// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/models/profile.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/profile_controller.dart';
import 'package:alfred_client/services/profile_avatar_service.dart';
import 'package:alfred_client/services/profile_service.dart';

import '../support/fake_messaging_services.dart';

class _FakeProfileService extends ProfileService {
  _FakeProfileService() : super(createTestSupabaseClient());

  Map<String, Object?>? lastUpdate;

  @override
  Future<UserProfile> updateProfile({
    required String userId,
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
    String? coverUrl,
    bool clearCoverUrl = false,
  }) async {
    lastUpdate = {
      'userId': userId,
      'displayName': displayName,
      'bio': bio,
      'pronouns': pronouns,
      'avatarUrl': avatarUrl,
      'coverUrl': clearCoverUrl ? null : coverUrl,
    };
    return UserProfile(
      summary: ProfileSummary(
        id: userId,
        username: 'user',
        displayName: displayName,
        avatarUrl: avatarUrl,
        coverUrl: clearCoverUrl ? null : coverUrl,
        pronouns: pronouns,
      ),
      bio: bio,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }
}

class _FakeAvatarService extends ProfileAvatarService {
  _FakeAvatarService() : super(createTestSupabaseClient());

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    return 'https://cdn.example/$userId/avatar.$extension';
  }

  @override
  Future<String> uploadCover({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    return 'https://cdn.example/$userId/cover.$extension';
  }
}

/// Wiring: ProfileController → ProfileCoordinator → _LiveProfileEffects.
void main() {
  group('profile wiring', () {
    const userId = 'user-1';
    late _FakeProfileService profileService;
    late ProfileController controller;

    setUp(() {
      profileService = _FakeProfileService();
      controller = ProfileController(
        userId: userId,
        profileService: profileService,
        avatarService: _FakeAvatarService(),
      );
    });

    test('save attraversa coordinator ed effects live', () async {
      final saved = await controller.save(
        displayName: 'Alice Updated',
        bio: 'Ciao',
        pronouns: 'she/her',
      );

      expect(saved.summary.displayName, 'Alice Updated');
      expect(profileService.lastUpdate?['displayName'], 'Alice Updated');
      expect(controller.isSaving, isFalse);
    });

    test('uploadAndSaveAvatar attraversa macchina UploadAvatar', () async {
      final saved = await controller.uploadAndSaveAvatar(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
        contentType: 'image/png',
        displayName: 'Alice Updated',
        bio: 'Ciao',
        pronouns: 'she/her',
      );

      expect(saved.summary.displayName, 'Alice Updated');
      expect(saved.avatarUrl, contains('avatar.png'));
      expect(profileService.lastUpdate?['avatarUrl'], contains('avatar.png'));
      expect(controller.isUploadingAvatar, isFalse);
    });

    test('uploadAvatar resta sul percorso coordinator', () async {
      final url = await controller.uploadAvatar(
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: 'png',
        contentType: 'image/png',
      );

      expect(url, contains('avatar.png'));
      expect(controller.isUploadingAvatar, isFalse);
    });
  });
}
