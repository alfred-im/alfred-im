// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../config/chat_media_config.dart';
import 'media_probe_timeout.dart';

Future<int> readVideoDurationSeconds({
  required Uint8List bytes,
  required String extension,
}) async {
  final tempDir = await getTemporaryDirectory();
  final path =
      '${tempDir.path}/probe_${DateTime.now().microsecondsSinceEpoch}.$extension';
  final file = File(path);
  try {
    await file.writeAsBytes(bytes, flush: true);
    final controller = VideoPlayerController.file(file);
    await withMediaProbeTimeout<void>(
      controller.initialize(),
      onTimeout: () => throw TimeoutException('video duration probe'),
    );
    final seconds = controller.value.duration.inSeconds
        .clamp(1, ChatMediaConfig.maxVideoDurationSeconds);
    await controller.dispose();
    return seconds;
  } catch (_) {
    return 1;
  } finally {
    if (await file.exists()) {
      await file.delete().catchError((_) => file);
    }
  }
}
