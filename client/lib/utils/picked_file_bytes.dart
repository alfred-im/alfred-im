// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picked_file_bytes_stub.dart'
    if (dart.library.io) 'picked_file_bytes_io.dart' as platform;

/// Reads picker bytes when [PlatformFile.bytes] is null (large files / web).
Future<Uint8List?> readPickedFileBytes(PlatformFile file) async {
  final direct = file.bytes;
  if (direct != null && direct.isNotEmpty) {
    return Uint8List.fromList(direct);
  }

  final stream = file.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    await stream.forEach(builder.add);
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  }

  return platform.readPickedFileBytesFromPath(file.path);
}
