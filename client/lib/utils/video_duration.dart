// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'video_duration_stub.dart'
    if (dart.library.io) 'video_duration_io.dart'
    if (dart.library.html) 'video_duration_web.dart' as platform;

Future<int> readVideoDurationSeconds({
  required Uint8List bytes,
  required String extension,
}) =>
    platform.readVideoDurationSeconds(bytes: bytes, extension: extension);
