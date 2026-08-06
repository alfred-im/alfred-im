// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:alfred_client/machines/profile/profile_effects.dart';
import 'package:alfred_client/machines/profile/profile_machine.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProfileEffects implements ProfileEffects {
  int saveCount = 0;
  int uploadCount = 0;
  int refreshCount = 0;
  String? lastDisplayName;
  String? lastBio;
  String? lastPronouns;
  String? lastAvatarUrl;
  String? lastCoverUrl;
  bool lastClearCoverUrl = false;
  Uint8List? lastUploadBytes;
  String? lastUploadExtension;
  String? lastUploadContentType;
  bool uploadThrows = false;

  @override
  Future<void> saveProfile({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
    String? coverUrl,
    bool clearCoverUrl = false,
  }) async {
    saveCount++;
    lastDisplayName = displayName;
    lastBio = bio;
    lastPronouns = pronouns;
    lastAvatarUrl = avatarUrl;
    lastCoverUrl = coverUrl;
    lastClearCoverUrl = clearCoverUrl;
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    uploadCount++;
    lastUploadBytes = bytes;
    lastUploadExtension = extension;
    lastUploadContentType = contentType;
    if (uploadThrows) {
      throw Exception('upload failed');
    }
    return 'https://cdn.example/avatar.png';
  }

  @override
  Future<String> uploadCover({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    uploadCount++;
    lastUploadBytes = bytes;
    lastUploadExtension = extension;
    lastUploadContentType = contentType;
    if (uploadThrows) {
      throw Exception('upload failed');
    }
    return 'https://cdn.example/cover.png';
  }

  @override
  Future<void> refreshAuthProfile() async {
    refreshCount++;
  }
}

Uint8List _avatarBytes() => Uint8List.fromList([1, 2, 3]);

void main() {
  group('ProfileMachine save', () {
    test('starts idle', () {
      final machine = ProfileMachine(_RecordingProfileEffects());

      expect(machine.editState, ProfileEditState.idle);
    });

    test('SaveProfile → saving and calls effect', () async {
      final effects = _RecordingProfileEffects();
      final machine = ProfileMachine(effects);

      await machine.send(
        const SaveProfile(
          displayName: 'Alice',
          bio: 'Hello',
          pronouns: 'she/her',
          avatarUrl: 'https://cdn.example/old.png',
        ),
      );

      expect(machine.editState, ProfileEditState.saving);
      expect(effects.saveCount, 1);
      expect(effects.lastDisplayName, 'Alice');
      expect(effects.lastBio, 'Hello');
      expect(effects.lastPronouns, 'she/her');
      expect(effects.lastAvatarUrl, 'https://cdn.example/old.png');
    });

    test('ProfileSaved → idle', () async {
      final machine = ProfileMachine(_RecordingProfileEffects())
        ..editState = ProfileEditState.saving;

      await machine.send(const ProfileSaved());

      expect(machine.editState, ProfileEditState.idle);
    });

    test('ProfileSaveFailed → idle', () async {
      final machine = ProfileMachine(_RecordingProfileEffects())
        ..editState = ProfileEditState.saving;

      await machine.send(const ProfileSaveFailed());

      expect(machine.editState, ProfileEditState.idle);
    });
  });

  group('ProfileMachine avatar upload', () {
    test('UploadAvatar uploads then saves with new avatar URL', () async {
      final effects = _RecordingProfileEffects();
      final machine = ProfileMachine(effects);
      final bytes = _avatarBytes();

      await machine.send(
        UploadAvatar(
          bytes: bytes,
          extension: 'png',
          contentType: 'image/png',
          displayName: 'Alice',
          bio: 'Bio',
          pronouns: 'she/her',
        ),
      );

      expect(effects.uploadCount, 1);
      expect(effects.lastUploadBytes, bytes);
      expect(effects.lastUploadExtension, 'png');
      expect(effects.lastUploadContentType, 'image/png');
      expect(effects.saveCount, 1);
      expect(effects.lastAvatarUrl, 'https://cdn.example/avatar.png');
      expect(effects.lastDisplayName, 'Alice');
      expect(machine.editState, ProfileEditState.saving);
    });

    test('UploadAvatar upload failure → idle', () async {
      final effects = _RecordingProfileEffects()..uploadThrows = true;
      final machine = ProfileMachine(effects);

      await machine.send(
        UploadAvatar(
          bytes: _avatarBytes(),
          extension: 'png',
          contentType: 'image/png',
          displayName: 'Alice',
        ),
      );

      expect(effects.uploadCount, 1);
      expect(effects.saveCount, 0);
      expect(machine.editState, ProfileEditState.idle);
    });

    test('AvatarUploadFailed → idle', () async {
      final machine = ProfileMachine(_RecordingProfileEffects())
        ..editState = ProfileEditState.uploadingAvatar;

      await machine.send(const AvatarUploadFailed());

      expect(machine.editState, ProfileEditState.idle);
    });
  });
}
