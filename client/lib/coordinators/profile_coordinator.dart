// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import '../machines/profile/profile_effects.dart';
import '../machines/profile/profile_machine.dart';
import '../models/profile.dart';
import '../services/profile_avatar_service.dart';
import '../services/profile_service.dart';

/// Stato edit profilo esposto alla UI tramite [ProfileController].
class ProfileEditUiState {
  bool isSaving = false;
  bool isUploadingAvatar = false;
  String? error;
}

/// Orchestrazione save/upload avatar profilo proprio.
class ProfileCoordinator {
  ProfileCoordinator({
    required this._userId,
    required this._profileService,
    required this._avatarService,
    required this._onStateChanged,
  }) {
    _machine = ProfileMachine(_LiveProfileEffects._(this));
  }

  final String _userId;
  final ProfileService _profileService;
  final ProfileAvatarService _avatarService;
  final void Function() _onStateChanged;
  late final ProfileMachine _machine;
  final ProfileEditUiState state = ProfileEditUiState();

  ProfileMachine get machine => _machine;

  bool get isSaving => state.isSaving;
  bool get isUploadingAvatar => state.isUploadingAvatar;
  String? get error => state.error;

  Future<UserProfile> save({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
  }) async {
    state.error = null;
    _notify();
    await _machine.send(
      SaveProfile(
        displayName: displayName,
        bio: bio,
        pronouns: pronouns,
        avatarUrl: avatarUrl,
      ),
    );
    if (state.error != null) {
      throw StateError(state.error!);
    }
    return _lastSavedProfile!;
  }

  UserProfile? _lastSavedProfile;

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    state.error = null;
    state.isUploadingAvatar = true;
    _notify();
    try {
      return await _avatarService.uploadAvatar(
        bytes: bytes,
        userId: _userId,
        extension: extension,
        contentType: contentType,
      );
    } catch (e) {
      state.error = e.toString();
      rethrow;
    } finally {
      state.isUploadingAvatar = false;
      _notify();
    }
  }

  void _syncSavingFromMachine() {
    state.isSaving = _machine.editState == ProfileEditState.saving ||
        _machine.editState == ProfileEditState.uploadingAvatar;
  }

  void _notify() => _onStateChanged();
}

class _LiveProfileEffects implements ProfileEffects {
  _LiveProfileEffects._(this._coordinator);

  final ProfileCoordinator _coordinator;

  ProfileCoordinator get _c => _coordinator;

  @override
  Future<void> saveProfile({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
  }) async {
    try {
      _c._lastSavedProfile = await _c._profileService.updateProfile(
        userId: _c._userId,
        displayName: displayName,
        bio: bio,
        pronouns: pronouns,
        avatarUrl: avatarUrl,
      );
      _c.state.error = null;
      await _c._machine.send(const ProfileSaved());
    } catch (e) {
      _c.state.error = e.toString();
      await _c._machine.send(const ProfileSaveFailed());
    } finally {
      _c._syncSavingFromMachine();
      _c._notify();
    }
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) {
    return _c.uploadAvatar(
      bytes: bytes,
      extension: extension,
      contentType: contentType,
    );
  }

  @override
  Future<void> refreshAuthProfile() async {}
}
