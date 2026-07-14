// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'image_bytes.dart';

Future<Uint8List> convertHeicToJpeg(Uint8List heic) async {
  final jpeg = await FlutterImageCompress.compressWithList(
    heic,
    format: CompressFormat.jpeg,
    quality: 90,
  );
  if (jpeg.isEmpty) {
    throw UnsupportedImageFormatException.heicConversionFailed();
  }
  return jpeg;
}

Future<NormalizedImageBytes> prepareImageForUpload(Uint8List bytes) async {
  final format = detectImageFormat(bytes);
  if (format == DetectedImageFormat.heic) {
    final jpeg = await convertHeicToJpeg(bytes);
    if (detectImageFormat(jpeg) != DetectedImageFormat.jpeg) {
      throw UnsupportedImageFormatException.heicConversionFailed();
    }
    return NormalizedImageBytes(
      bytes: jpeg,
      mime: 'image/jpeg',
      extension: 'jpg',
    );
  }
  return normalizeImageBytes(bytes);
}
