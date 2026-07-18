// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../machines/messaging/messaging_adapters.dart';
import '../machines/messaging/messaging_conversation_state.dart';
import '../machines/messaging/messaging_coordinator.dart';
import '../machines/messaging/messaging_effects.dart';
import '../models/message.dart';
import '../services/inbox_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/outbound_message_queue.dart';
import '../services/profile_service.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.userId,
    required this.peerProfileId,
    required this.messageService,
    required this.messageMediaService,
    required this.inboxService,
    this.profileService,
    this.peerIsGroup = false,
    this.onMessagesChanged,
    this.hasValidSession,
    OutboundMessageQueue? outboundQueue,
  }) {
    _state = MessagingConversationState();
    _effects = MessagesControllerEffects(
      state: _state,
      userId: userId,
      peerProfileId: peerProfileId,
      messageService: messageService,
      messageMediaService: messageMediaService,
      inboxService: inboxService,
      profileService: profileService,
      peerIsGroup: peerIsGroup,
      onMessagesChanged: onMessagesChanged,
      hasValidSession: hasValidSession,
      outboundQueue: outboundQueue,
      onChanged: notifyListeners,
    );
    _coordinator = MessagingCoordinator(
      state: _state,
      effects: _effects,
      onChanged: notifyListeners,
      peerIsGroup: peerIsGroup,
    );
    _effects.onSendLifecycleStart = _coordinator.notifySendStarted;
    _effects.onSendLifecycleEnd = _coordinator.notifySendEnded;
    _adapters = MessagingAdapters(_coordinator);
    unawaited(_adapters.init());
  }

  static const sessionExpiredMessage =
      MessagesControllerEffects.sessionExpiredMessage;

  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final bool Function()? hasValidSession;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final ProfileService? profileService;
  final bool peerIsGroup;

  late final MessagingConversationState _state;
  late final MessagesControllerEffects _effects;
  late final MessagingCoordinator _coordinator;
  late final MessagingAdapters _adapters;

  List<ChatMessage> get messages => _coordinator.messages;
  set messages(List<ChatMessage> value) => _state.messages = value;
  bool get isLoading => _coordinator.isLoading;
  bool get isSending => _coordinator.isSending;
  @visibleForTesting
  set isSending(bool value) {
    if (value) {
      _coordinator.notifySendStarted();
    } else {
      _coordinator.notifySendEnded(false);
    }
  }
  String? get error => _coordinator.error;

  static String outboundQueueKey({
    required String userId,
    required String peerProfileId,
  }) =>
      '$userId|$peerProfileId';

  Future<void> reload() => _adapters.reload();

  Future<void> load() => _adapters.load();

  Future<void> send(String body) => _adapters.sendText(body);

  Future<void> sendGif(Uint8List bytes) => _adapters.sendGif(bytes);

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) =>
      _adapters.sendImage(bytes: bytes, caption: caption);

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) =>
      _adapters.sendVideoFromPicker(file: file, caption: caption);

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) =>
      _adapters.sendVideo(
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
      _adapters.sendVoice(bytes: bytes, durationMs: durationMs);

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) =>
      _adapters.sendLocation(latitude: latitude, longitude: longitude);

  Future<void> retryMessage(String clientId) =>
      _adapters.retryMessage(clientId);

  @override
  void dispose() {
    _adapters.dispose();
    super.dispose();
  }
}
