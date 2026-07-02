import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/voice_config.dart';
import '../services/voice_recording_service.dart';
import '../theme/alfred_colors.dart';
import '../utils/duration_format.dart';
import 'voice_message_content.dart';

typedef VoiceSendCallback = Future<void> Function(Uint8List bytes, int durationMs);

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.enabled = true,
    this.onSend,
    this.onSendGif,
    this.onSendVoice,
    this.onSendLocation,
  });

  final bool enabled;
  final Future<void> Function(String body)? onSend;
  final Future<void> Function(Uint8List bytes)? onSendGif;
  final VoiceSendCallback? onSendVoice;
  final Future<void> Function()? onSendLocation;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

enum _VoicePhase { idle, recording, locked, preview }

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _recorder = VoiceRecordingService();

  StreamSubscription<double>? _ampSub;
  Timer? _uiTimer;
  double? _pointerOriginY;

  _VoicePhase _voicePhase = _VoicePhase.idle;
  double _level = 0;
  bool _cancelArmed = false;
  bool _lockArmed = false;
  VoiceRecordingResult? _preview;

  @override
  void dispose() {
    _controller.dispose();
    _ampSub?.cancel();
    _uiTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.onSend == null) return;
    _controller.clear();
    await widget.onSend!(text);
  }

  Future<void> _pickGif() async {
    if (!widget.enabled || widget.onSendGif == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
      allowMultiple: false,
    );

    final bytes = result?.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;
    await widget.onSendGif!(Uint8List.fromList(bytes));
  }

  Future<void> _shareLocation() async {
    if (!widget.enabled || widget.onSendLocation == null) return;
    await widget.onSendLocation!();
  }

  void _stopUiTracking() {
    _ampSub?.cancel();
    _ampSub = null;
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  Future<void> _beginVoiceHold() async {
    if (!widget.enabled || widget.onSendVoice == null || _voicePhase != _VoicePhase.idle) {
      return;
    }

    try {
      await _recorder.start();
      _ampSub = _recorder.amplitudeStream.listen((value) {
        if (mounted) setState(() => _level = value);
      });
      _uiTimer?.cancel();
      _uiTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (mounted) setState(() {});
      });
      setState(() {
        _voicePhase = _VoicePhase.recording;
        _cancelArmed = false;
        _lockArmed = false;
        _preview = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microfono non disponibile. Controlla i permessi del browser o del dispositivo.',
          ),
        ),
      );
    }
  }

  Future<void> _endVoiceHold() async {
    if (_voicePhase == _VoicePhase.locked || _voicePhase == _VoicePhase.preview) {
      return;
    }
    if (_voicePhase != _VoicePhase.recording) return;

    _pointerOriginY = null;
    _stopUiTracking();

    if (_cancelArmed) {
      await _recorder.cancel();
      setState(() => _voicePhase = _VoicePhase.idle);
      return;
    }

    final result = await _recorder.stop();
    setState(() => _voicePhase = _VoicePhase.idle);
    if (result != null) {
      await widget.onSendVoice!(result.bytes, result.durationMs);
    }
  }

  void _onVoiceDragUpdate(double dy) {
    if (_voicePhase != _VoicePhase.recording) return;
    setState(() {
      _lockArmed = dy < -VoiceConfig.lockSwipeThresholdPx;
      _cancelArmed = dy > VoiceConfig.cancelSwipeThresholdPx;
    });
    if (_lockArmed) {
      setState(() => _voicePhase = _VoicePhase.locked);
    }
  }

  Future<void> _stopLockedRecording() async {
    if (_voicePhase != _VoicePhase.locked) return;
    _stopUiTracking();
    final result = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _preview = result;
      _voicePhase = _VoicePhase.preview;
      _level = 0;
    });
  }

  Future<void> _cancelLockedRecording() async {
    if (_voicePhase != _VoicePhase.locked) return;
    _stopUiTracking();
    await _recorder.cancel();
    if (!mounted) return;
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _level = 0;
      _preview = null;
    });
  }

  Future<void> _sendLockedRecording() async {
    if (_voicePhase != _VoicePhase.locked) return;
    _stopUiTracking();
    final result = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _voicePhase = _VoicePhase.idle;
      _level = 0;
      _preview = null;
    });
    if (result == null) return;
    if (result.durationMs < VoiceConfig.minDurationMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota vocale troppo breve.')),
      );
      return;
    }
    await widget.onSendVoice!(result.bytes, result.durationMs);
  }

  Future<void> _discardPreview() async {
    setState(() {
      _preview = null;
      _voicePhase = _VoicePhase.idle;
    });
  }

  Future<void> _sendPreview() async {
    final result = _preview;
    if (result == null || widget.onSendVoice == null) return;
    setState(() {
      _preview = null;
      _voicePhase = _VoicePhase.idle;
    });
    await widget.onSendVoice!(result.bytes, result.durationMs);
  }

  Widget _buildVoiceOverlay() {
    final elapsed = formatVoiceDurationMs(_recorder.elapsedMs);

    return Positioned(
      left: 8,
      right: 8,
      bottom: 64,
      child: Material(
        elevation: 10,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        color: AlfredColors.panel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_voicePhase == _VoicePhase.recording) ...[
                Row(
                  children: [
                    Icon(
                      _cancelArmed ? Icons.delete_outline : Icons.mic,
                      color: _cancelArmed ? Colors.redAccent : AlfredColors.unreadBadge,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _cancelArmed
                            ? 'Rilascia per annullare'
                            : 'Scorri ↑ blocca · ↓ annulla',
                        style: const TextStyle(
                          color: AlfredColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      elapsed,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LiveVoiceWaveform(
                  level: _level,
                  activeColor:
                      _cancelArmed ? Colors.redAccent : AlfredColors.unreadBadge,
                ),
              ],
              if (_voicePhase == _VoicePhase.locked) ...[
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AlfredColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Registrazione bloccata · $elapsed',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _stopLockedRecording,
                      child: const Text('Anteprima'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LiveVoiceWaveform(level: _level, activeColor: AlfredColors.charcoal),
                const SizedBox(height: 4),
                const Text(
                  'Usa Invia nella barra in basso, oppure Anteprima per ascoltare prima.',
                  style: TextStyle(color: AlfredColors.textSecondary, fontSize: 12),
                ),
              ],
              if (_voicePhase == _VoicePhase.preview && _preview != null) ...[
                Row(
                  children: [
                    const Icon(Icons.graphic_eq, color: AlfredColors.charcoal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anteprima · ${formatVoiceDurationMs(_preview!.durationMs)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Elimina',
                      onPressed: _discardPreview,
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                    ),
                    FilledButton.icon(
                      onPressed: _sendPreview,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Invia'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AlfredColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingAction() {
    if (_hasText) {
      return Material(
        color: AlfredColors.charcoal,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: widget.enabled ? _submit : null,
          borderRadius: BorderRadius.circular(24),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.send, color: Colors.white, size: 22),
          ),
        ),
      );
    }

    if (_voicePhase == _VoicePhase.locked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Annulla registrazione',
            onPressed: widget.enabled ? () => unawaited(_cancelLockedRecording()) : null,
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent,
          ),
          Material(
            color: AlfredColors.charcoal,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: widget.enabled ? () => unawaited(_sendLockedRecording()) : null,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      );
    }

    return Listener(
      onPointerDown: widget.enabled && widget.onSendVoice != null
          ? (event) {
              _pointerOriginY = event.position.dy;
              unawaited(_beginVoiceHold());
            }
          : null,
      onPointerMove: widget.enabled && _pointerOriginY != null
          ? (event) {
              final origin = _pointerOriginY;
              if (origin == null) return;
              _onVoiceDragUpdate(event.position.dy - origin);
            }
          : null,
      onPointerUp: widget.enabled ? (_) => unawaited(_endVoiceHold()) : null,
      onPointerCancel: widget.enabled ? (_) => unawaited(_endVoiceHold()) : null,
      child: Material(
        color: _voicePhase == _VoicePhase.recording
            ? AlfredColors.unreadBadge
            : AlfredColors.charcoal,
        borderRadius: BorderRadius.circular(24),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.mic, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AlfredColors.panel,
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.enabled ? _pickGif : null,
                    tooltip: 'Invia GIF',
                    icon: Icon(
                      Icons.gif_box_outlined,
                      color: widget.enabled
                          ? AlfredColors.textPrimary
                          : AlfredColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.enabled ? () => unawaited(_shareLocation()) : null,
                    tooltip: 'Condividi posizione',
                    icon: Icon(
                      Icons.location_on_outlined,
                      color: widget.enabled
                          ? AlfredColors.textPrimary
                          : AlfredColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled && _voicePhase == _VoicePhase.idle,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Scrivi un messaggio',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: widget.enabled ? (_) => _submit() : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildTrailingAction(),
                ],
              ),
            ),
            if (_voicePhase != _VoicePhase.idle) _buildVoiceOverlay(),
          ],
        ),
      ),
    );
  }
}
