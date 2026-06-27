import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'voice_encoding_platform.dart';

class VoiceEncodingImpl implements VoiceEncodingPlatform {
  @override
  bool get isSourceAlreadyCanonical => true;

  @override
  Future<Uint8List> toCanonicalWebm({
    required String sourcePath,
    required Uint8List? sourceBytes,
  }) async {
    if (sourceBytes != null && sourceBytes.isNotEmpty) {
      return sourceBytes;
    }

    if (sourcePath.startsWith('blob:') || sourcePath.startsWith('http')) {
      final response = await http.get(Uri.parse(sourcePath));
      if (response.statusCode >= 400) {
        throw StateError('Failed to read recorded audio (${response.statusCode})');
      }
      return response.bodyBytes;
    }

    if (kIsWeb) {
      throw StateError('Web voice recording returned an unreadable source.');
    }

    throw StateError('Voice source bytes missing.');
  }
}

VoiceEncodingPlatform get voiceEncodingPlatform => VoiceEncodingImpl();
