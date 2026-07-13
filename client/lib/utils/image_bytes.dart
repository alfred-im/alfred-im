// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Sniffed image container — independent from picker-reported MIME.
enum DetectedImageFormat { jpeg, png, webp, heic, unknown }

/// Canonical bytes + MIME for chat-media upload (PROM-CHAT-MEDIA-001).
class NormalizedImageBytes {
  const NormalizedImageBytes({
    required this.bytes,
    required this.mime,
    required this.extension,
  });

  final Uint8List bytes;
  final String mime;
  final String extension;
}

DetectedImageFormat detectImageFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return DetectedImageFormat.jpeg;
  }

  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return DetectedImageFormat.png;
  }

  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return DetectedImageFormat.webp;
  }

  if (bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand.startsWith('hei') ||
        brand == 'mif1' ||
        brand == 'hevc' ||
        brand == 'avif') {
      return DetectedImageFormat.heic;
    }
  }

  return DetectedImageFormat.unknown;
}

String extensionForDetectedFormat(DetectedImageFormat format) {
  switch (format) {
    case DetectedImageFormat.jpeg:
      return 'jpg';
    case DetectedImageFormat.png:
      return 'png';
    case DetectedImageFormat.webp:
      return 'webp';
    case DetectedImageFormat.heic:
      return 'heic';
    case DetectedImageFormat.unknown:
      return 'bin';
  }
}

/// Validates magic bytes and returns canonical MIME/extension for upload.
///
/// Throws [UnsupportedImageFormatException] when the file is HEIC/HEIF or
/// another unsupported container (common when iOS reports `image/jpeg`).
NormalizedImageBytes normalizeImageBytes(Uint8List bytes) {
  switch (detectImageFormat(bytes)) {
    case DetectedImageFormat.jpeg:
      return NormalizedImageBytes(
        bytes: bytes,
        mime: 'image/jpeg',
        extension: 'jpg',
      );
    case DetectedImageFormat.png:
      return NormalizedImageBytes(
        bytes: bytes,
        mime: 'image/png',
        extension: 'png',
      );
    case DetectedImageFormat.webp:
      return NormalizedImageBytes(
        bytes: bytes,
        mime: 'image/webp',
        extension: 'webp',
      );
    case DetectedImageFormat.heic:
      throw UnsupportedImageFormatException.heicConversionFailed();
    case DetectedImageFormat.unknown:
      throw UnsupportedImageFormatException.unsupported();
  }
}

class UnsupportedImageFormatException implements Exception {
  UnsupportedImageFormatException._(this.userMessage);

  factory UnsupportedImageFormatException.heicConversionFailed() =>
      UnsupportedImageFormatException._(
        'Impossibile convertire la foto HEIC. Riprova con un’altra immagine.',
      );

  factory UnsupportedImageFormatException.unsupported() =>
      UnsupportedImageFormatException._(
        'Formato immagine non supportato. Usa JPEG, PNG o WebP.',
      );

  final String userMessage;

  @override
  String toString() => userMessage;
}
