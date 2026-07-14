// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../config/chat_media_config.dart';
import 'package:file_picker/file_picker.dart';

String videoExtensionFromFilename(String? filename) {
  final name = filename?.trim() ?? '';
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'mp4';
  return name.substring(dot + 1).toLowerCase();
}

bool isSupportedVideoExtension(String extension) =>
    ChatMediaConfig.videoExtensions.contains(extension.toLowerCase());

/// Extension from picker metadata, then filename.
String videoExtensionFromPickedFile(PlatformFile file) {
  final fromPicker = file.extension?.trim().toLowerCase();
  if (fromPicker != null && fromPicker.isNotEmpty) {
    return fromPicker;
  }
  return videoExtensionFromFilename(file.name);
}
