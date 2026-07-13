// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

import '../config/chat_media_config.dart';

Future<int> readVideoDurationSeconds({
  required Uint8List bytes,
  required String extension,
}) async {
  final mime = ChatMediaConfig.videoMimeForExtension(extension) ?? 'video/mp4';
  final blobParts = <web.BlobPart>[bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  try {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    final seconds = controller.value.duration.inSeconds
        .clamp(1, ChatMediaConfig.maxVideoDurationSeconds);
    await controller.dispose();
    return seconds;
  } catch (_) {
    return 1;
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
