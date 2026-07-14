// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Canonical chat photo/video limits — contract for client, storage, RPC.
abstract final class ChatMediaConfig {
  static const imageMaxBytes = 10 * 1024 * 1024;
  static const videoMaxBytes = 50 * 1024 * 1024;
  static const maxVideoDurationSeconds = 3600;

  static const imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const videoExtensions = ['mp4', 'webm'];

  /// Web SharedPreferences cannot hold large video blobs; keep in RAM only.
  static const webOutboundPersistMaxBytes = 4 * 1024 * 1024;

  static bool shouldPersistOutboundMediaOnWeb(int bytes) =>
      bytes <= webOutboundPersistMaxBytes;

  static const imageMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const videoMimeTypes = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
  };

  static String? imageMimeForExtension(String? extension) {
    if (extension == null) return null;
    return imageMimeTypes[extension.toLowerCase()];
  }

  static String? videoMimeForExtension(String? extension) {
    if (extension == null) return null;
    return videoMimeTypes[extension.toLowerCase()];
  }

  static String imageExtensionForMime(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        return 'jpg';
    }
  }

  static String videoExtensionForMime(String mime) {
    return mime == 'video/webm' ? 'webm' : 'mp4';
  }
}
