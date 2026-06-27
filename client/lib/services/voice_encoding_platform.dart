import 'dart:typed_data';

import '../config/voice_config.dart';

/// Platform hook: produce canonical WebM/Opus bytes from a recorded temp file.
abstract class VoiceEncodingPlatform {
  Future<Uint8List> toCanonicalWebm({
    required String sourcePath,
    required Uint8List? sourceBytes,
  });

  bool get isSourceAlreadyCanonical;

  static VoiceEncodingPlatform get instance => throw UnimplementedError(
        'VoiceEncodingPlatform has no implementation for this platform.',
      );
}

bool isCanonicalVoiceMime(String? mime) =>
    mime != null && mime.toLowerCase().startsWith(VoiceConfig.canonicalMime);
