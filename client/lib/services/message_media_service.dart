// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import '../config/chat_media_config.dart';
import '../config/voice_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
      maxBytes: VoiceConfig.maxBytes,
    );
  }

  Future<String> uploadImage({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    return _upload(
      bytes: bytes,
      userId: userId,
      extension: extension,
      contentType: contentType,
      maxBytes: ChatMediaConfig.imageMaxBytes,
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
      maxBytes: VoiceConfig.maxBytes,
    );
  }

  Future<String> uploadVideo({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    return _upload(
      bytes: bytes,
      userId: userId,
      extension: extension,
      contentType: contentType,
      maxBytes: ChatMediaConfig.videoMaxBytes,
    );
  }

  Future<String> _upload({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
    required int maxBytes,
  }) async {
    if (bytes.length > maxBytes) {
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
