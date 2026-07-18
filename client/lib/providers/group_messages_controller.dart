// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../coordinators/group_messages_coordinator.dart';
import '../models/message.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/profile_service.dart';

/// Facade UI conversazione gruppo — orchestrazione in [GroupMessagesCoordinator].
class GroupMessagesController extends ChangeNotifier {
  GroupMessagesController({
    required this.userId,
    required this.messageService,
    required this.messageMediaService,
    required this.profileService,
    this.onMessagesChanged,
  }) {
    _coordinator = GroupMessagesCoordinator(
      userId: userId,
      messageService: messageService,
      messageMediaService: messageMediaService,
      profileService: profileService,
      onStateChanged: notifyListeners,
      onMessagesChanged: onMessagesChanged,
    );
  }

  final String userId;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final ProfileService profileService;
  final Future<void> Function()? onMessagesChanged;
  late final GroupMessagesCoordinator _coordinator;

  List<ChatMessage> get messages => _coordinator.state.messages;

  bool get isLoading => _coordinator.state.isLoading;

  bool get isSending => _coordinator.state.isSending;

  String? get error => _coordinator.state.error;

  Future<void> load() => _coordinator.load();

  Future<void> reload() => _coordinator.reload();

  Future<void> send(String body) => _coordinator.send(body);

  Future<void> sendGif(Uint8List bytes) => _coordinator.sendGif(bytes);

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) =>
      _coordinator.sendVoice(bytes: bytes, durationMs: durationMs);

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) =>
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

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) =>
      _coordinator.sendLocation(latitude: latitude, longitude: longitude);

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }
}
