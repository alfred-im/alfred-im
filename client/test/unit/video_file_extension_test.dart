// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:alfred_client/utils/video_file_extension.dart';

void main() {
  test('videoExtensionFromFilename parses extension', () {
    expect(videoExtensionFromFilename('clip.MP4'), 'mp4');
    expect(videoExtensionFromFilename('noext'), 'mp4');
  });

  test('isSupportedVideoExtension accepts mp4 and webm only', () {
    expect(isSupportedVideoExtension('mp4'), isTrue);
    expect(isSupportedVideoExtension('webm'), isTrue);
    expect(isSupportedVideoExtension('mov'), isFalse);
  });
}
