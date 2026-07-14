// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/picked_file_bytes.dart';

void main() {
  test('readPickedFileBytes returns direct bytes when present', () async {
    final bytes = await readPickedFileBytes(
      PlatformFile(name: 'clip.mp4', size: 3, bytes: Uint8List.fromList([1, 2, 3])),
    );

    expect(bytes, Uint8List.fromList([1, 2, 3]));
  });

  test('readPickedFileBytes reads from stream when bytes are null', () async {
    final controller = StreamController<List<int>>();
    final file = PlatformFile(
      name: 'clip.mp4',
      size: 3,
      readStream: controller.stream,
    );

    final future = readPickedFileBytes(file);
    controller.add([1, 2]);
    controller.add([3]);
    await controller.close();

    expect(await future, Uint8List.fromList([1, 2, 3]));
  });
}
