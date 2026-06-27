import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config/voice_config.dart';
import 'voice_encoding_service.dart';

class VoiceRecordingResult {
  const VoiceRecordingResult({
    required this.bytes,
    required this.durationMs,
  });

  final Uint8List bytes;
  final int durationMs;
}

class VoiceRecordingService {
  VoiceRecordingService({
    AudioRecorder? recorder,
    VoiceEncodingPlatform? encoding,
  })  : _recorder = recorder ?? AudioRecorder(),
        _encoding = encoding ?? voiceEncodingPlatform;

  final AudioRecorder _recorder;
  final VoiceEncodingPlatform _encoding;

  String? _activePath;
  DateTime? _startedAt;
  Timer? _maxDurationTimer;
  final _amplitudeController = StreamController<double>.broadcast();

  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (await _recorder.isRecording()) return;

    if (!await ensurePermission()) {
      throw StateError('Microphone permission denied');
    }

    _startedAt = DateTime.now();

    final config = const RecordConfig(
      encoder: AudioEncoder.opus,
      sampleRate: 48000,
      numChannels: 1,
      bitRate: 64000,
    );

    if (kIsWeb) {
      final path =
          'voice_${DateTime.now().microsecondsSinceEpoch}.${VoiceConfig.fileExtension}';
      await _recorder.start(config, path: path);
      _activePath = path;
    } else {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 48000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: path,
      );
      _activePath = path;
    }

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(
      const Duration(seconds: VoiceConfig.maxDurationSeconds),
      () {
        unawaited(stop());
      },
    );

    unawaited(_pollAmplitude());
  }

  Future<void> _pollAmplitude() async {
    while (await _recorder.isRecording()) {
      final amplitude = await _recorder.getAmplitude();
      final normalized = ((amplitude.current + 45) / 45).clamp(0.0, 1.0);
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(normalized);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  int get elapsedMs {
    final started = _startedAt;
    if (started == null) return 0;
    return DateTime.now().difference(started).inMilliseconds;
  }

  Future<VoiceRecordingResult?> stop({bool discard = false}) async {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    if (!await _recorder.isRecording()) {
      return null;
    }

    final path = await _recorder.stop();
    final durationMs = elapsedMs;
    _startedAt = null;

    if (discard || durationMs < VoiceConfig.minDurationMs) {
      await _cleanupSource(path ?? _activePath);
      _activePath = null;
      return null;
    }

    final sourcePath = path ?? _activePath;
    _activePath = null;
    if (sourcePath == null) {
      return null;
    }

    final bytes = await _encoding.toCanonicalWebm(
      sourcePath: sourcePath,
      sourceBytes: null,
    );

    if (!kIsWeb) {
      await _cleanupSource(sourcePath);
    }

    if (bytes.length > VoiceConfig.maxBytes) {
      throw StateError('Voice note exceeds size limit');
    }

    return VoiceRecordingResult(bytes: bytes, durationMs: durationMs);
  }

  Future<void> cancel() => stop(discard: true);

  Future<void> _cleanupSource(String? path) async {
    if (path == null || kIsWeb) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> dispose() async {
    _maxDurationTimer?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}
