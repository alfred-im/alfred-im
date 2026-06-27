import 'voice_encoding_platform.dart';
import 'voice_encoding_io.dart' if (dart.library.html) 'voice_encoding_web.dart'
    as voice_encoding_impl;

export 'voice_encoding_platform.dart';

VoiceEncodingPlatform get voiceEncodingPlatform =>
    voice_encoding_impl.voiceEncodingPlatform;
