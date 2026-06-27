import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';
import '../utils/duration_format.dart';

class VoiceMessageContent extends StatefulWidget {
  const VoiceMessageContent({
    super.key,
    required this.message,
    required this.isMine,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  State<VoiceMessageContent> createState() => _VoiceMessageContentState();
}

class _VoiceMessageContentState extends State<VoiceMessageContent> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _isLoading = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final seconds = widget.message.durationSeconds ?? 0;
    _duration = Duration(seconds: seconds);
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.pause());
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.startsWith('pending://')) return;

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (_player.audioSource == null) {
      setState(() => _isLoading = true);
      await _player.setUrl(url);
      final detected = _player.duration;
      if (detected != null && mounted) {
        setState(() => _duration = detected);
      }
      setState(() => _isLoading = false);
    }

    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.message.mediaUrl;
    final isPending = url == null || url.startsWith('pending://');
    final totalSeconds = _duration.inSeconds > 0
        ? _duration.inSeconds
        : (widget.message.durationSeconds ?? 0);
    final progress = totalSeconds <= 0
        ? 0.0
        : (_position.inMilliseconds / (totalSeconds * 1000)).clamp(0.0, 1.0);

    final accent = widget.isMine ? AlfredColors.charcoal : AlfredColors.accentBlue;

    return SizedBox(
      width: 248,
      child: Row(
        children: [
          Material(
            color: accent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: isPending ? null : _togglePlayback,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: isPending || _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VoiceWaveform(
                  progress: progress,
                  activeColor: accent,
                  seed: widget.message.id.hashCode,
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying || _position > Duration.zero
                      ? formatVoiceDurationMs(_position.inMilliseconds)
                      : formatVoiceDuration(totalSeconds),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AlfredColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({
    required this.progress,
    required this.activeColor,
    required this.seed,
  });

  final double progress;
  final Color activeColor;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final random = math.Random(seed);
    final bars = List<double>.generate(28, (_) => 0.25 + random.nextDouble() * 0.75);

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 8 + bars[i] * 18,
                  decoration: BoxDecoration(
                    color: (i / bars.length) <= progress
                        ? activeColor
                        : activeColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LiveVoiceWaveform extends StatelessWidget {
  const LiveVoiceWaveform({
    super.key,
    required this.level,
    required this.activeColor,
  });

  final double level;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(18, (index) {
          final phase = (index / 18) * math.pi;
          final animated = (math.sin(phase + level * math.pi * 2) + 1) / 2;
          final height = 6 + animated * 24 * (0.35 + level * 0.65);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                height: height,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.45 + level * 0.55),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
