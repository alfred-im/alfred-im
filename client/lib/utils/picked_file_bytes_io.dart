// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readPickedFileBytesFromPath(String? path) async {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
