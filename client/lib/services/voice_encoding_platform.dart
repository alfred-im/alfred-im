// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

/// Platform hook: produce canonical WebM/Opus bytes from a recorded temp file.
abstract class VoiceEncodingPlatform {
  Future<Uint8List> toCanonicalWebm({
    required String sourcePath,
    required Uint8List? sourceBytes,
  });

  static VoiceEncodingPlatform get instance => throw UnimplementedError(
        'VoiceEncodingPlatform has no implementation for this platform.',
      );
}
