// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/message.dart';
import 'conversation_load_machine.dart';
import 'messaging_conversation_state.dart';
import 'messaging_effects.dart';
import 'messaging_message_list.dart';
import 'outbound_send_machine.dart';
import 'realtime_attachment_machine.dart';

/// Compone le tre macchine messaging — unico ingresso per [MessagesController].
class MessagingCoordinator {
  MessagingCoordinator({
    required this.state,
    required this.effects,
    required this.onChanged,
    this.peerIsGroup = false,
  });

  final MessagingConversationState state;
  final MessagingEffects effects;
  final VoidCallback onChanged;
  final bool peerIsGroup;

  final ConversationLoadMachine loadMachine = ConversationLoadMachine();
  final OutboundSendMachine sendMachine = OutboundSendMachine();
  final RealtimeAttachmentMachine realtimeMachine = RealtimeAttachmentMachine();

  RealtimeChannel? _channel;

  List<ChatMessage> get messages => state.messages;
  String? get error => state.error;
  bool get isLoading => loadMachine.state == ConversationLoadState.loading;
  bool get isSending => sendMachine.state == OutboundSendState.sending;

  Future<void> init() async {
    await load();
    await effects.restoreFailedFromQueue();
    if (state.messages.any(
      (m) => m.isMine && m.status == MessageStatus.failed,
    )) {
      sendMachine.send(const FailedQueueRestored());
    }
    await effects.markRead();
    attachRealtime();
    effects.startRetryTimer(() => unawaited(_processRetries()));
    _notify();
  }

  Future<void> reload() async {
    loadMachine.send(const RefreshConversation());
    state.error = null;
    _notify();
    await load();
  }

  Future<void> load() async {
    if (!effects.ensureValidSession()) {
      loadMachine.send(const SessionExpired());
      _notify();
      return;
    }
    loadMachine.send(const LoadMessages());
    _notify();
    try {
      await effects.fetchAndSetMessages();
      state.error = null;
      loadMachine.send(const ConversationReady());
    } catch (e) {
      state.error = e.toString();
      loadMachine.send(const LoadFailed());
    }
    _notify();
  }

  void attachRealtime() {
    if (realtimeMachine.state == RealtimeAttachmentState.attached) {
      return;
    }
    _channel = effects.attachRealtime(_handleRealtimeMessage);
    realtimeMachine.send(const AttachRealtime());
    _notify();
  }

  void detachRealtime() {
    effects.disposeRealtime(_channel);
    _channel = null;
    realtimeMachine.send(const DetachRealtime());
    _notify();
  }

  void _handleRealtimeMessage(ChatMessage message) {
    realtimeMachine.send(RealtimeReceived(message));
    state.messages = replaceOrInsertMessage(
      state.messages,
      withTimeLabel(message),
    );
    if (peerIsGroup) {
      unawaited(effects.enrichAuthorNamesIfNeeded());
    } else {
      _notify();
    }
  }

  Future<void> sendText(String body) async {
    if (body.trim().isEmpty || isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendText(body);
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendGif(bytes);
  }

  Future<void> sendImage({required Uint8List bytes, String? caption}) async {
    if (bytes.isEmpty || isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendImage(bytes: bytes, caption: caption);
  }

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {
    if (isSending) {
      state.error = 'Invio già in corso, attendi il completamento.';
      _notify();
      return;
    }
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendVideoFromPicker(file: file, caption: caption);
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (isSending) {
      state.error = 'Invio già in corso, attendi il completamento.';
      _notify();
      return;
    }
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendVideo(
      bytes: bytes,
      extension: extension,
      mime: mime,
      durationSeconds: durationSeconds,
      caption: caption,
    );
  }

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) async {
    if (bytes.isEmpty || isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendVoice(bytes: bytes, durationMs: durationMs);
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.sendLocation(latitude: latitude, longitude: longitude);
  }

  Future<void> retryMessage(String clientId) async {
    if (isSending) return;
    if (loadMachine.state == ConversationLoadState.sessionBlocked) return;
    await effects.retryMessage(clientId);
  }

  Future<void> _processRetries() async {
    if (isSending) return;
    await effects.processRetries();
  }

  void notifySendStarted() {
    sendMachine.send(const SendStarted());
    _notify();
  }

  void notifySendEnded(bool failed) {
    sendMachine.send(failed ? const ContentSendFailed() : const ContentSent());
    _notify();
  }

  void dispose() {
    detachRealtime();
    effects.disposeQueue();
  }

  void _notify() => onChanged();
}
