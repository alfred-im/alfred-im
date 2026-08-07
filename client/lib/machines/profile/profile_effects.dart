// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Effetti profile → [ProfileController] e servizi collegati.
abstract class ProfileEffects {
  Future<void> saveProfile({
    required String displayName,
    String? bio,
    String? pronouns,
    String? avatarUrl,
    String? coverUrl,
    bool clearCoverUrl = false,
  });

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });

  Future<String> uploadCover({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });

  Future<void> refreshAuthProfile();
}
