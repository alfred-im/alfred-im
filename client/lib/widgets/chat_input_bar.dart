// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/chat_media_config.dart';
import '../config/location_config.dart';
import '../config/voice_config.dart';
import '../models/location_reading.dart';
import '../services/location_service.dart';
import '../services/voice_recording_service.dart';
import '../theme/alfred_colors.dart';
import '../utils/duration_format.dart';
import '../utils/picked_file_bytes.dart';
import '../utils/video_duration.dart';
import '../utils/video_file_extension.dart';
import 'location_map_preview.dart';
import 'voice_message_content.dart';
import 'package:image_picker/image_picker.dart';

typedef VoiceSendCallback = Future<void> Function(Uint8List bytes, int durationMs);
typedef LocationSendCallback = Future<void> Function(
  double latitude,
  double longitude,
);
typedef ImageSendCallback = Future<void> Function(
  Uint8List bytes, {
  String? caption,
});
typedef VideoSendCallback = Future<void> Function(
  Uint8List bytes, {
  required String extension,
  required String mime,
  required int durationSeconds,
  String? caption,
});

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.enabled = true,
    this.hintText = 'Scrivi un messaggio',
    this.onSend,
    this.onSendGif,
    this.onSendImage,
    this.onSendVideo,
    this.onSendVoice,
    this.onSendLocation,
  });

  final bool enabled;
  final String hintText;
  final Future<void> Function(String body)? onSend;
  final Future<void> Function(Uint8List bytes)? onSendGif;
  final ImageSendCallback? onSendImage;
  final VideoSendCallback? onSendVideo;
  final VoiceSendCallback? onSendVoice;
  final LocationSendCallback? onSendLocation;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

enum _VoicePhase { idle, recording, locked, preview }

enum _LocationPhase { idle, sharing }

class _ChatInputBarState extends State<ChatInputBar> {
  final _barKey = GlobalKey();
  final _controller = TextEditingController();
  final _recorder = VoiceRecordingService();
  final _locationService = LocationService();

  StreamSubscription<double>? _ampSub;
  StreamSubscription<LocationReading>? _locationSub;
  Timer? _uiTimer;
  double? _pointerOriginY;
  OverlayEntry? _locationOverlayEntry;

  _VoicePhase _voicePhase = _VoicePhase.idle;
  _LocationPhase _locationPhase = _LocationPhase.idle;
  LocationReading? _locationPreview;
  double _level = 0;
  bool _cancelArmed = false;
  bool _lockArmed = false;
  VoiceRecordingResult? _preview;

  @override
  void dispose() {
    _hideLocationOverlay();
    _controller.dispose();
    _ampSub?.cancel();
    _locationSub?.cancel();
    _uiTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  bool get _showGif => widget.onSendGif != null;
  bool get _showAttachments =>
      widget.onSendImage != null || widget.onSendVideo != null;
  bool get _showLocation => widget.onSendLocation != null;
  bool get _showVoice => widget.onSendVoice != null;

  String? _takeCaption() {
    final caption = _controller.text.trim();
    if (caption.isEmpty) return null;
    _controller.clear();
    setState(() {});
    return caption;
  }

  Future<void> _showAttachmentMenu() async {
    if (!widget.enabled || _isComposerLocked) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onSendImage != null) ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galleria foto'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_pickImage(ImageSource.gallery));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Fotocamera'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_pickImage(ImageSource.camera));
                  },
                ),
              ],
              if (widget.onSendVideo != null)
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Video'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_pickVideo());
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!widget.enabled || widget.onSendImage == null) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 4096,
      maxHeight: 4096,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final caption = _takeCaption();

    await widget.onSendImage!(
      bytes,
      caption: caption,
    );
  }

  Future<void> _pickVideo() async {
    if (!widget.enabled || widget.onSendVideo == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
      withReadStream: true,
      allowMultiple: false,
    );

    final file = result?.files.single;
    if (file == null) return;

    final bytes = await readPickedFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile leggere il video selezionato'),
        ),
      );
      return;
    }

    final extension = videoExtensionFromFilename(file.name);
    if (!isSupportedVideoExtension(extension)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato video non supportato. Usa MP4 o WebM.'),
        ),
      );
      return;
    }

    final mime =
        ChatMediaConfig.videoMimeForExtension(extension) ?? 'video/mp4';
    final durationSeconds = await readVideoDurationSeconds(
      bytes: bytes,
      extension: extension,
    );
    final caption = _takeCaption();

    await widget.onSendVideo!(
      bytes,
      extension: extension,
      mime: mime,
      durationSeconds: durationSeconds,
      caption: caption,
    );
  }

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

  bool get _isComposerLocked =>
      _voicePhase != _VoicePhase.idle || _locationPhase != _LocationPhase.idle;

  Future<void> _beginLocationShare() async {
    if (!widget.enabled ||
        widget.onSendLocation == null ||
        _locationPhase != _LocationPhase.idle ||
        _voicePhase != _VoicePhase.idle) {
      return;
    }

    setState(() {
      _locationPhase = _LocationPhase.sharing;
      _locationPreview = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showLocationOverlay();
    });

    try {
      final stream = _locationService.watchCurrentPosition();
      _locationSub = stream.listen(
        (reading) {
          if (!mounted) return;
          setState(() => _locationPreview = reading);
          _locationOverlayEntry?.markNeedsBuild();
        },
        onError: (Object error) {
          if (!mounted) return;
          _cancelLocationShare();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error is LocationServiceException
                    ? error.message
                    : 'Impossibile rilevare la posizione.',
              ),
            ),
          );
        },
      );
    } on LocationServiceException catch (error) {
      if (!mounted) return;
      setState(() => _locationPhase = _LocationPhase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  void _cancelLocationShare() {
    _locationSub?.cancel();
    _locationSub = null;
    setState(() {
      _locationPhase = _LocationPhase.idle;
      _locationPreview = null;
    });
    _hideLocationOverlay();
  }

  Future<void> _confirmLocationShare() async {
    final preview = _locationPreview;
    if (preview == null || widget.onSendLocation == null) return;

    _locationSub?.cancel();
    _locationSub = null;
    setState(() {
      _locationPhase = _LocationPhase.idle;
      _locationPreview = null;
    });
    _hideLocationOverlay();

    await widget.onSendLocation!(
      preview.roundedLatitude,
      preview.roundedLongitude,
    );
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

  Widget _buildLocationMapSlot(LocationReading? preview) {
    return SizedBox(
      width: double.infinity,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: preview == null
            ? const ColoredBox(
                color: AlfredColors.border,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Rilevamento posizione…',
                        style: TextStyle(
                          color: AlfredColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : LocationMapPreview(
                latitude: preview.latitude,
                longitude: preview.longitude,
                width: double.infinity,
                height: 160,
              ),
      ),
    );
  }

  void _showLocationOverlay() {
    if (!mounted || _locationPhase == _LocationPhase.idle) return;
    if (_locationOverlayEntry == null) {
      _locationOverlayEntry = OverlayEntry(
        builder: (context) => _buildLocationOverlayLayer(context),
      );
      Overlay.of(context).insert(_locationOverlayEntry!);
    } else {
      _locationOverlayEntry!.markNeedsBuild();
    }
  }

  void _hideLocationOverlay() {
    _locationOverlayEntry?.remove();
    _locationOverlayEntry = null;
  }

  double _locationOverlayBottom(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final barBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (barBox == null || !barBox.hasSize) {
      return MediaQuery.viewPaddingOf(context).bottom + 64;
    }
    return screenHeight - barBox.localToGlobal(Offset.zero).dy;
  }

  Widget _buildLocationOverlayLayer(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cancelLocationShare,
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: _locationOverlayBottom(context),
            child: _buildLocationOverlayCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationOverlayCard() {
    final preview = _locationPreview;
    final canSend = preview != null;

    return Material(
      elevation: 10,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      color: AlfredColors.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLocationMapSlot(preview),
            const SizedBox(height: 10),
            Text(
              preview == null
                  ? 'In attesa del segnale GPS…'
                  : LocationConfig.formatCoordinates(
                      preview.latitude,
                      preview.longitude,
                    ),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: preview == null
                    ? AlfredColors.textSecondary
                    : AlfredColors.textPrimary,
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 4),
              Text(
                preview.accuracyLabel,
                style: const TextStyle(
                  color: AlfredColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _cancelLocationShare,
                  child: const Text('Annulla'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canSend
                      ? () => unawaited(_confirmLocationShare())
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Invia posizione'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AlfredColors.charcoal,
                    disabledBackgroundColor: AlfredColors.border,
                  ),
                ),
              ],
            ),
          ],
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

    if (!_showVoice) {
      return const SizedBox(width: 44, height: 44);
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
      key: _barKey,
      color: AlfredColors.panel,
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(
              ignoring: _locationPhase != _LocationPhase.idle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                children: [
                  if (_showAttachments)
                    IconButton(
                      onPressed: widget.enabled && !_isComposerLocked
                          ? () => unawaited(_showAttachmentMenu())
                          : null,
                      tooltip: 'Allega',
                      icon: Icon(
                        Icons.attach_file_outlined,
                        color: widget.enabled
                            ? AlfredColors.textPrimary
                            : AlfredColors.textSecondary,
                      ),
                    ),
                  if (_showGif)
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
                  if (_showLocation)
                    IconButton(
                      onPressed: widget.enabled && !_isComposerLocked
                          ? () => unawaited(_beginLocationShare())
                          : null,
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
                      enabled: widget.enabled && !_isComposerLocked,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            ),
            if (_voicePhase != _VoicePhase.idle) _buildVoiceOverlay(),
          ],
        ),
      ),
    );
  }
}
