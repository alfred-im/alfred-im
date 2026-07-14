// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers deterministic path_provider answers for VM widget/unit tests.
void setUpMockPathProvider({String root = '/tmp/alfred_test'}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    switch (call.method) {
      case 'getApplicationSupportDirectory':
        return '$root/support';
      case 'getTemporaryDirectory':
        return '$root/temp';
      case 'getApplicationDocumentsDirectory':
        return '$root/documents';
      case 'getLibraryDirectory':
        return '$root/library';
      case 'getDownloadsDirectory':
        return '$root/downloads';
      default:
        return null;
    }
  });
}
