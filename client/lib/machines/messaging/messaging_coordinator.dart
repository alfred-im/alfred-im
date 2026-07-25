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
  });

  final MessagingConversationState state;
  final MessagingEffects effects;
  final VoidCallback onChanged;

  final ConversationLoadMachine loadMachine = ConversationLoadMachine();
  final OutboundSendMachine sendMachine = OutboundSendMachine();
  final RealtimeAttachmentMachine realtimeMachine = RealtimeAttachmentMachine();

  RealtimeChannel? _channel;

  List<ChatMessage> get messages =>
      effects.messageStore.snapshotFor(effects.scope).messages;
  String? get error => state.error;
  bool get isLoading => loadMachine.state == ConversationLoadState.loading;
  bool get isSending => sendMachine.state == OutboundSendState.sending;
  bool get hasMoreOlder =>
      effects.messageStore.snapshotFor(effects.scope).hasMoreOlder;
  bool get isLoadingOlder =>
      effects.messageStore.snapshotFor(effects.scope).isLoadingOlder;

  Future<void> init() async {
    await load();
    if (effects.isDisposed) return;
    await effects.restoreFailedFromQueue();
    if (effects.isDisposed) return;
    if (effects.messageStore.snapshotFor(effects.scope).messages.any(
      (m) => m.isMine && m.status == MessageStatus.failed,
    )) {
      sendMachine.send(const FailedQueueRestored());
    }
    await effects.markRead();
    if (effects.isDisposed) return;
    attachRealtime();
    if (effects.isDisposed) return;
    effects.startRetryTimer(() => unawaited(_processRetries()));
    _notify();
  }

  Future<void> reload() async {
    loadMachine.send(const RefreshConversation());
    state.error = null;
    effects.messageStore.beginLoad(effects.scope);
    _notify();
    await load();
  }

  Future<void> loadOlderMessages() async {
    if (!hasMoreOlder || isLoadingOlder || isLoading) return;
    final applied = await effects.fetchAndPrependOlderMessages();
    if (!applied || effects.isDisposed) return;
    _notify();
  }

  static const _fetchScopeRetryAttempts = 8;
  static const _fetchScopeRetryDelay = Duration(milliseconds: 50);

  Future<void> load() async {
    if (!effects.ensureValidSession()) {
      loadMachine.send(const SessionExpired());
      _notify();
      return;
    }
    loadMachine.send(const LoadMessages());
    _notify();
    try {
      var applied = false;
      for (var attempt = 0; attempt < _fetchScopeRetryAttempts; attempt++) {
        applied = await effects.fetchAndSetMessages();
        if (effects.isDisposed) return;
        if (applied) break;
        if (attempt < _fetchScopeRetryAttempts - 1) {
          await Future<void>.delayed(_fetchScopeRetryDelay);
          if (!effects.ensureValidSession()) {
            loadMachine.send(const SessionExpired());
            _notify();
            return;
          }
        }
      }
      if (!applied && !effects.isDisposed) {
        state.error = MessagesControllerEffects.sessionExpiredMessage;
        loadMachine.send(const SessionExpired());
        _notify();
        return;
      }
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
    effects.messageStore.mutateMessages(
      effects.scope,
      (messages) => replaceOrInsertMessage(
        messages,
        withTimeLabel(message),
      ),
    );
    if (effects.hasGroupPeerAuthorEnrichment) {
      unawaited(effects.enrichAuthorNamesIfNeeded());
    } else {
      _notify();
    }
  }

  Future<void> sendText(String body) async {
    if (body.trim().isEmpty || _guardSend()) return;
    await effects.sendText(body);
  }

  Future<void> sendGif(Uint8List bytes) async {
    if (bytes.isEmpty || _guardSend()) return;
    await effects.sendGif(bytes);
  }

  Future<void> sendImage({required Uint8List bytes, String? caption}) async {
    if (bytes.isEmpty || _guardSend()) return;
    await effects.sendImage(bytes: bytes, caption: caption);
  }

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) async {
    if (_guardSend(notifyOnBusy: true)) return;
    await effects.sendVideoFromPicker(file: file, caption: caption);
  }

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) async {
    if (_guardSend(notifyOnBusy: true)) return;
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
    if (bytes.isEmpty || _guardSend()) return;
    await effects.sendVoice(bytes: bytes, durationMs: durationMs);
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (_guardSend()) return;
    await effects.sendLocation(latitude: latitude, longitude: longitude);
  }

  Future<void> retryMessage(String clientId) async {
    if (_guardSend()) return;
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

  /// `true` when send must be blocked (busy or session expired).
  bool _guardSend({bool notifyOnBusy = false}) {
    if (isSending) {
      if (notifyOnBusy) {
        state.error = 'Invio già in corso, attendi il completamento.';
        _notify();
      }
      return true;
    }
    if (loadMachine.state == ConversationLoadState.sessionBlocked) {
      return true;
    }
    return false;
  }

  void _notify() {
    if (effects.isDisposed) return;
    onChanged();
  }
}
