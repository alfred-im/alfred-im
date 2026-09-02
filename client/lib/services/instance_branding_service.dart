// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Upload logo/favicon istanza nel bucket `instance-branding` (solo owner).
class InstanceBrandingService {
  InstanceBrandingService(this._client);

  final SupabaseClient _client;
  static const bucket = 'instance-branding';
  static const maxBytes = 2 * 1024 * 1024;
  static const _uuid = Uuid();

  Future<String> uploadLogo({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) {
    return _uploadAsset(
      kind: 'logo',
      bytes: bytes,
      extension: extension,
      contentType: contentType,
    );
  }

  Future<String> uploadFavicon({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) {
    return _uploadAsset(
      kind: 'favicon',
      bytes: bytes,
      extension: extension,
      contentType: contentType,
    );
  }

  Future<String> uploadWordmark({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) {
    return _uploadAsset(
      kind: 'wordmark',
      bytes: bytes,
      extension: extension,
      contentType: contentType,
    );
  }

  Future<String> _uploadAsset({
    required String kind,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.length > maxBytes) {
      throw StateError('Immagine troppo grande (max 2 MB)');
    }

    final normalizedExt = extension.toLowerCase();
    final path = 'branding/$kind/${_uuid.v4()}.$normalizedExt';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteByPublicUrl(String? publicUrl) async {
    final path = _storagePathFromPublicUrl(publicUrl);
    if (path == null) return;
    await _client.storage.from(bucket).remove([path]);
  }

  String? _storagePathFromPublicUrl(String? publicUrl) {
    if (publicUrl == null || publicUrl.trim().isEmpty) return null;
    final marker = '/storage/v1/object/public/$bucket/';
    final index = publicUrl.indexOf(marker);
    if (index < 0) return null;
    return publicUrl.substring(index + marker.length);
  }
}
