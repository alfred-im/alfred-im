// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import '../services/message_media_service.dart';
import 'image_bytes.dart';
import 'prepare_image_for_upload.dart';

/// Upload path condiviso tra peer messaging e broadcast gruppo.
class OutboundMediaSendHelper {
  OutboundMediaSendHelper({
    required MessageMediaService mediaService,
    required this.userId,
  }) : _mediaService = mediaService;

  final MessageMediaService _mediaService;
  final String userId;

  Future<String> uploadGif(Uint8List bytes) {
    return _mediaService.uploadGif(bytes: bytes, userId: userId);
  }

  Future<String> uploadVoice(Uint8List bytes) {
    return _mediaService.uploadVoice(bytes: bytes, userId: userId);
  }

  Future<OutboundImageUpload> prepareAndUploadImage(Uint8List bytes) async {
    final normalized = await prepareImageForUpload(bytes);
    final mediaUrl = await uploadNormalizedImage(normalized);
    return OutboundImageUpload(mediaUrl: mediaUrl, normalized: normalized);
  }

  Future<String> uploadNormalizedImage(NormalizedImageBytes normalized) {
    return _mediaService.uploadImage(
      bytes: normalized.bytes,
      userId: userId,
      extension: normalized.extension,
      contentType: normalized.mime,
    );
  }

  Future<String> uploadVideo({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) {
    return _mediaService.uploadVideo(
      bytes: bytes,
      userId: userId,
      extension: extension,
      contentType: contentType,
    );
  }
}

class OutboundImageUpload {
  const OutboundImageUpload({
    required this.mediaUrl,
    required this.normalized,
  });

  final String mediaUrl;
  final NormalizedImageBytes normalized;
}
