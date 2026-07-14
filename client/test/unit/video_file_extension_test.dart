// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/video_file_extension.dart';

void main() {
  test('videoExtensionFromFilename parses extension', () {
    expect(videoExtensionFromFilename('clip.MP4'), 'mp4');
    expect(videoExtensionFromFilename('noext'), 'mp4');
  });

  test('videoExtensionFromPickedFile uses filename extension', () {
    final file = PlatformFile(name: 'clip.webm', size: 1);
    expect(videoExtensionFromPickedFile(file), 'webm');
  });

  test('isSupportedVideoExtension accepts mp4 and webm only', () {
    expect(isSupportedVideoExtension('mp4'), isTrue);
    expect(isSupportedVideoExtension('webm'), isTrue);
    expect(isSupportedVideoExtension('mov'), isFalse);
  });
}
