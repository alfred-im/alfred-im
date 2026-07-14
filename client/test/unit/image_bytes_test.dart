// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:alfred_client/utils/image_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects JPEG magic bytes', () {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    expect(detectImageFormat(bytes), DetectedImageFormat.jpeg);
    final normalized = normalizeImageBytes(bytes);
    expect(normalized.mime, 'image/jpeg');
    expect(normalized.extension, 'jpg');
  });

  test('detects HEIC disguised as JPEG filename', () {
    final bytes = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, // ....ftyp
      0x68, 0x65, 0x69, 0x63, // heic
      0x00, 0x00, 0x00, 0x00,
    ]);
    expect(detectImageFormat(bytes), DetectedImageFormat.heic);
    expect(
      () => normalizeImageBytes(bytes),
      throwsA(isA<UnsupportedImageFormatException>()),
    );
  });
}
