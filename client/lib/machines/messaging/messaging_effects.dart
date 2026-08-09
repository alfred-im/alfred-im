// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/conversation_scope.dart';
import '../../models/message.dart';
import 'conversation_message_store.dart';

/// Porta effetti messaging → [MessagingCoordinator] e servizi collegati.
abstract class MessagingEffects {
  ConversationScope get scope;
  ConversationMessageStore get messageStore;
  bool get isDisposed;
  bool ensureValidSession();
  /// Scope commesso ancora attivo (navigation + sessione live).
  bool get isScopeActive;
  /// Carica messaggi; `false` se scope non più attivo (il coordinator può ritentare).
  Future<bool> fetchAndSetMessages();
  /// Carica pagina più vecchia; `false` se scope non più attivo.
  Future<bool> fetchAndPrependOlderMessages();
  Future<void> enrichAuthorNamesIfNeeded();
  bool get hasGroupPeerAuthorEnrichment;
  Future<void> markRead();
  RealtimeChannel? attachRealtime(
    void Function(ChatMessage message) onMessage, {
    void Function(String logicalMessageId)? onReactionFact,
  });
  Future<void> applyReaction({
    required String logicalMessageId,
    required String emoji,
  });
  Future<void> withdrawReaction({required String logicalMessageId});
  Future<void> refreshReactionsForLogicalId(String logicalMessageId);
  void disposeRealtime(RealtimeChannel? channel);
  void startRetryTimer(void Function() onTick);
  void stopRetryTimer();
  Future<void> restoreFailedFromQueue();
  Future<void> sendText(String body);
  Future<void> sendGif(Uint8List bytes);
  Future<void> sendImage({required Uint8List bytes, String? caption});
  Future<void> sendVideoFromPicker({required PlatformFile file, String? caption});
  Future<void> sendVideo({required Uint8List bytes, required String extension, required String mime, required int durationSeconds, String? caption});
  Future<void> sendVoice({required Uint8List bytes, required int durationMs});
  Future<void> sendLocation({required double latitude, required double longitude});
  Future<void> retryMessage(String clientId);
  Future<void> processRetries();
  void disposeQueue();
}
