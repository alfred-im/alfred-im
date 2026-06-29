import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAvatarService {
  ProfileAvatarService(this._client);

  final SupabaseClient _client;

  static const maxBytes = 2 * 1024 * 1024;

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.length > maxBytes) {
      throw StateError('Immagine troppo grande (max 2 MB)');
    }

    final normalizedExt = extension.toLowerCase();
    final path = '$userId/avatar.$normalizedExt';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}
