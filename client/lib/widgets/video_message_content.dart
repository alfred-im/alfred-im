// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';
import '../utils/duration_format.dart';

const double _videoMaxWidth = 280;
const double _videoMaxHeight = 200;

class VideoMessageContent extends StatefulWidget {
  const VideoMessageContent({super.key, required this.message});

  final ChatMessage message;

  @override
  State<VideoMessageContent> createState() => _VideoMessageContentState();
}

class _VideoMessageContentState extends State<VideoMessageContent> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty || url.startsWith('pending://')) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    if (url.startsWith('pending://')) {
      return const SizedBox(
        width: _videoMaxWidth,
        height: 120,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_failed) {
      return Container(
        width: _videoMaxWidth,
        height: 120,
        color: AlfredColors.border,
        alignment: Alignment.center,
        child: const Icon(
          Icons.videocam_off_outlined,
          color: AlfredColors.textSecondary,
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        width: _videoMaxWidth,
        height: 120,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final durationLabel = widget.message.durationSeconds != null
        ? formatVoiceDuration(widget.message.durationSeconds!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: _togglePlayback,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: _videoMaxWidth,
                  height: _videoMaxHeight,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                if (!controller.value.isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                  ),
              ],
            ),
          ),
        ),
        if (durationLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              durationLabel,
              style: const TextStyle(
                fontSize: 11,
                color: AlfredColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
