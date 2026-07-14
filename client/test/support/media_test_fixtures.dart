// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Minimal JPEG header (valid magic bytes for [detectImageFormat]).
final kJpegBytes = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
]);

/// HEIC/HEIF ftyp box (iPhone-style container).
final kHeicBytes = Uint8List.fromList([
  0x00,
  0x00,
  0x00,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x68,
  0x65,
  0x69,
  0x63,
  0x00,
  0x00,
  0x00,
  0x00,
]);

/// Tiny opaque payload standing in for MP4 during controller tests.
final kMp4Bytes = Uint8List.fromList(List<int>.generate(64, (i) => i % 256));
