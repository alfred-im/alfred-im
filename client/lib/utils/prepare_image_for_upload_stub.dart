// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'image_bytes.dart';

Future<Uint8List> convertHeicToJpeg(Uint8List heic) async {
  throw UnsupportedImageFormatException.heicConversionFailed();
}

Future<NormalizedImageBytes> prepareImageForUpload(Uint8List bytes) async {
  final format = detectImageFormat(bytes);
  if (format == DetectedImageFormat.heic) {
    final jpeg = await convertHeicToJpeg(bytes);
    return NormalizedImageBytes(
      bytes: jpeg,
      mime: 'image/jpeg',
      extension: 'jpg',
    );
  }
  return normalizeImageBytes(bytes);
}
