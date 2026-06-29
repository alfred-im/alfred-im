import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/voice_config.dart';

class MessageMediaService {
  MessageMediaService(this._client);

  final SupabaseClient _client;

  Future<String> uploadGif({
    required Uint8List bytes,
    required String userId,
  }) async {
    return _upload(
      bytes: bytes,
      userId: userId,
      extension: 'gif',
      contentType: 'image/gif',
    );
  }

  Future<String> uploadVoice({
    required Uint8List bytes,
    required String userId,
  }) async {
    return _upload(
      bytes: bytes,
      userId: userId,
      extension: VoiceConfig.fileExtension,
      contentType: VoiceConfig.canonicalMime,
    );
  }

  Future<String> _upload({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.length > VoiceConfig.maxBytes) {
      throw StateError('Media exceeds size limit');
    }

    final path = '$userId/${const Uuid().v4()}.$extension';
    await _client.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return _client.storage.from('chat-media').getPublicUrl(path);
  }
}
