// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'messaging_coordinator.dart';

/// Adapter UI → [MessagingCoordinator].
class MessagingAdapters {
  MessagingAdapters(this._coordinator);

  final MessagingCoordinator _coordinator;

  Future<void> init() => _coordinator.init();

  Future<void> load() => _coordinator.load();

  Future<void> reload() => _coordinator.reload();

  Future<void> sendText(String body) => _coordinator.sendText(body);

  Future<void> sendGif(Uint8List bytes) => _coordinator.sendGif(bytes);

  Future<void> sendImage({required Uint8List bytes, String? caption}) =>
      _coordinator.sendImage(bytes: bytes, caption: caption);

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) =>
      _coordinator.sendVideoFromPicker(file: file, caption: caption);

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) =>
      _coordinator.sendVideo(
        bytes: bytes,
        extension: extension,
        mime: mime,
        durationSeconds: durationSeconds,
        caption: caption,
      );

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) =>
      _coordinator.sendVoice(bytes: bytes, durationMs: durationMs);

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) =>
      _coordinator.sendLocation(latitude: latitude, longitude: longitude);

  Future<void> retryMessage(String clientId) =>
      _coordinator.retryMessage(clientId);

  void dispose() => _coordinator.dispose();
}
