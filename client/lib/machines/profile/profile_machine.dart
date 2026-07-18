// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'profile_effects.dart';

/// Stato edit profilo — `docs/model/uml/profile/profile-edit-state.puml`.
enum ProfileEditState {
  idle,
  saving,
  uploadingAvatar,
}

/// Eventi — `docs/domain/profile/commands-and-events.md`.
sealed class ProfileEvent {
  const ProfileEvent();
}

final class SaveProfile extends ProfileEvent {
  const SaveProfile({
    required this.displayName,
    this.bio,
    this.pronouns,
    this.avatarUrl,
  });
  final String displayName;
  final String? bio;
  final String? pronouns;
  final String? avatarUrl;
}

final class ProfileSaved extends ProfileEvent {
  const ProfileSaved();
}

final class ProfileSaveFailed extends ProfileEvent {
  const ProfileSaveFailed();
}

final class UploadAvatar extends ProfileEvent {
  const UploadAvatar({
    required this.bytes,
    required this.extension,
    required this.contentType,
    required this.displayName,
    this.bio,
    this.pronouns,
  });
  final Uint8List bytes;
  final String extension;
  final String contentType;
  final String displayName;
  final String? bio;
  final String? pronouns;
}

final class AvatarUploadFailed extends ProfileEvent {
  const AvatarUploadFailed();
}

/// Interprete statechart profile — allineato a UML.
///
/// Produzione: [ProfileCoordinator] + [ProfileController].
class ProfileMachine {
  ProfileMachine(this._effects);

  final ProfileEffects _effects;

  ProfileEditState editState = ProfileEditState.idle;

  Future<void> send(ProfileEvent event) async {
    switch (event) {
      case SaveProfile(:final displayName, :final bio, :final pronouns, :final avatarUrl):
        editState = ProfileEditState.saving;
        await _effects.saveProfile(
          displayName: displayName,
          bio: bio,
          pronouns: pronouns,
          avatarUrl: avatarUrl,
        );
      case ProfileSaved():
        editState = ProfileEditState.idle;
      case ProfileSaveFailed():
        editState = ProfileEditState.idle;
      case UploadAvatar(:final bytes, :final extension, :final contentType, :final displayName, :final bio, :final pronouns):
        editState = ProfileEditState.uploadingAvatar;
        try {
          final avatarUrl = await _effects.uploadAvatar(
            bytes: bytes,
            extension: extension,
            contentType: contentType,
          );
          await send(SaveProfile(
            displayName: displayName,
            bio: bio,
            pronouns: pronouns,
            avatarUrl: avatarUrl,
          ));
        } catch (_) {
          editState = ProfileEditState.idle;
        }
      case AvatarUploadFailed():
        editState = ProfileEditState.idle;
    }
  }
}
