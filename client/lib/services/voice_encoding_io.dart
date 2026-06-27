import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../config/voice_config.dart';
import 'voice_encoding_platform.dart';

class VoiceEncodingImpl implements VoiceEncodingPlatform {
  @override
  bool get isSourceAlreadyCanonical => false;

  @override
  Future<Uint8List> toCanonicalWebm({
    required String sourcePath,
    required Uint8List? sourceBytes,
  }) async {
    final input = File(sourcePath);
    if (!await input.exists()) {
      throw StateError('Recorded file not found.');
    }

    if (sourcePath.endsWith('.${VoiceConfig.fileExtension}')) {
      final bytes = await input.readAsBytes();
      if (bytes.isNotEmpty) {
        return bytes;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.${VoiceConfig.fileExtension}';

    final session = await FFmpegKit.execute(
      '-y -i "$sourcePath" -c:a libopus -b:a 64k -f webm "$outputPath"',
    );
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw StateError('Voice transcode failed: $logs');
    }

    final output = File(outputPath);
    final bytes = await output.readAsBytes();
    await output.delete().catchError((_) => output);
    return bytes;
  }
}

VoiceEncodingPlatform get voiceEncodingPlatform => VoiceEncodingImpl();
